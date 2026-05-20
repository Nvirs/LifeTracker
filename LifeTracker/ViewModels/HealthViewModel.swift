import Foundation
import SwiftUI
import Combine
import HealthKit


enum HealthAuthorizationState {
    case unknown
    case unauthorized
    case authorized
}

@MainActor
final class HealthViewModel: ObservableObject {
    @Published var summaryCards: [HealthSummaryCardData] = []
    @Published var bodyStats: [HealthBodyStatData] = []
    @Published var measurements: [HealthMeasurementData] = []
    @Published var photoItems: [HealthPhotoData] = []

    @Published var stepsEntries: [HealthDailyEntry] = []
    @Published var sleepEntries: [HealthDailyEntry] = []
    @Published var calorieEntries: [HealthDailyEntry] = []

    @Published var stepsValueText = "—"
    @Published var sleepValueText = "—"
    @Published var caloriesValueText = "—"
    @Published var stepsValue: Double = 0
    @Published var activeCaloriesValue: Double = 0

    @Published var authorizationState: HealthAuthorizationState = .unknown
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let healthKit = HealthKitManager.shared

    private let stepsGoal = 10000.0
    private let sleepGoalHours = 8.0
    private let caloriesGoal = 2200.0
    private let workoutsGoal = 5.0

    func requestAccessAndLoad() async {
        guard healthKit.isAvailable else {
            authorizationState = .unauthorized
            errorMessage = "Health data is not available on this device."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let granted = try await healthKit.requestAuthorization()
            authorizationState = granted ? .authorized : .unauthorized
            if granted {
                await loadData()
            } else {
                errorMessage = "Health access was denied."
            }
        } catch {
            authorizationState = .unauthorized
            errorMessage = "Unable to access Health data."
        }

        isLoading = false
    }

    func loadData() async {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? todayStart

        async let stepsQuantity = healthKit.fetchQuantitySum(for: .stepCount, from: todayStart, to: todayEnd, unit: .count())
        async let caloriesQuantity = healthKit.fetchQuantitySum(for: .activeEnergyBurned, from: todayStart, to: todayEnd, unit: .kilocalorie())
        async let sleepHours = healthKit.fetchSleepHours(from: todayStart, to: todayEnd)
        async let workoutsCount = healthKit.fetchWorkoutCount(from: weekStart, to: todayEnd)

        async let weightSamples = healthKit.fetchRecentQuantitySamples(for: .bodyMass, unit: HKUnit.gramUnit(with: .kilo), limit: 2)
        async let bodyFatSamples = healthKit.fetchRecentQuantitySamples(for: .bodyFatPercentage, unit: .percent(), limit: 2)
        async let bmiSamples = healthKit.fetchRecentQuantitySamples(for: .bodyMassIndex, unit: .count(), limit: 2)

        async let heartRate = healthKit.fetchMostRecentHeartRate()
        async let bloodGlucose = healthKit.fetchMostRecentBloodGlucose()

        let steps = await stepsQuantity
        let calories = await caloriesQuantity
        let sleep = await sleepHours
        let workouts = await workoutsCount

        stepsValue = steps
        activeCaloriesValue = calories

        stepsValueText = formatNumber(steps, decimals: 0)
        caloriesValueText = "\(formatNumber(calories, decimals: 0)) kcal"
        sleepValueText = formatHours(sleep)

        let workoutsText = "\(workouts)"

        summaryCards = [
            HealthSummaryCardData(title: "Steps", value: stepsValueText, goal: "/ 10,000", progress: progress(steps, goal: stepsGoal), color: .green),
            HealthSummaryCardData(title: "Sleep", value: sleepValueText, goal: "/ 8h", progress: progress(sleep, goal: sleepGoalHours), color: .indigo),
            HealthSummaryCardData(title: "Calories", value: "\(formatNumber(calories, decimals: 0))", goal: "/ 2,200 kcal", progress: progress(calories, goal: caloriesGoal), color: .orange),
            HealthSummaryCardData(title: "Workouts", value: workoutsText, goal: "/ 5 wk", progress: progress(Double(workouts), goal: workoutsGoal), color: .blue)
        ]

        let todayLabel = shortDateFormatter.string(from: now)

        stepsEntries = steps > 0 ? [HealthDailyEntry(date: todayLabel, value: stepsValueText, progress: progress(steps, goal: stepsGoal))] : []
        sleepEntries = sleep > 0 ? [HealthDailyEntry(date: todayLabel, value: sleepValueText, progress: progress(sleep, goal: sleepGoalHours))] : []
        calorieEntries = calories > 0 ? [HealthDailyEntry(date: todayLabel, value: "\(formatNumber(calories, decimals: 0)) kcal", progress: progress(calories, goal: caloriesGoal))] : []

        bodyStats = buildBodyStats(weightSamples: await weightSamples, bodyFatSamples: await bodyFatSamples, bmiSamples: await bmiSamples)
        measurements = buildMeasurements(heartRate: await heartRate, bloodGlucose: await bloodGlucose)
        photoItems = []
    }

    private func buildBodyStats(weightSamples: [(value: Double, date: Date)], bodyFatSamples: [(value: Double, date: Date)], bmiSamples: [(value: Double, date: Date)]) -> [HealthBodyStatData] {
        let weight = buildDelta(samples: weightSamples, unitLabel: "kg", decimals: 1, scale: 1)
        let bodyFat = buildDelta(samples: bodyFatSamples, unitLabel: "%", decimals: 1, scale: 100)
        let bmi = buildDelta(samples: bmiSamples, unitLabel: "", decimals: 1, scale: 1)

        return [
            HealthBodyStatData(title: "Weight", value: weight.value, delta: weight.delta, deltaColor: weight.deltaColor),
            HealthBodyStatData(title: "Body fat", value: bodyFat.value, delta: bodyFat.delta, deltaColor: bodyFat.deltaColor),
            HealthBodyStatData(title: "BMI", value: bmi.value, delta: bmi.delta, deltaColor: bmi.deltaColor)
        ]
    }

    private func buildDelta(samples: [(value: Double, date: Date)], unitLabel: String, decimals: Int, scale: Double) -> (value: String, delta: String, deltaColor: Color) {
        guard let current = samples.first?.value else {
            return ("—", "—", .secondary)
        }

        let formattedValue = formatNumber(current * scale, decimals: decimals)
        let valueText = unitLabel.isEmpty ? formattedValue : "\(formattedValue) \(unitLabel)"

        guard samples.count > 1 else {
            return (valueText, "—", .secondary)
        }

        let previous = samples[1].value
        let deltaValue = (current - previous) * scale
        let deltaText = formatSigned(deltaValue, decimals: decimals)
        let deltaColor: Color = deltaValue < 0 ? .green : (deltaValue > 0 ? .red : .secondary)
        let fullDelta = unitLabel.isEmpty ? deltaText : "\(deltaText) \(unitLabel)"

        return (valueText, fullDelta, deltaColor)
    }

    private func buildMeasurements(heartRate: (value: Double, date: Date)?, bloodGlucose: (value: Double, date: Date)?) -> [HealthMeasurementData] {
        var items: [HealthMeasurementData] = []

        if let heartRate {
            let value = "\(formatNumber(heartRate.value, decimals: 0)) bpm"
            items.append(HealthMeasurementData(icon: "waveform.path.ecg", title: "Heart rate", value: value, date: longDateFormatter.string(from: heartRate.date)))
        }

        if let bloodGlucose {
            let value = "\(formatNumber(bloodGlucose.value, decimals: 1)) mmol/L"
            items.append(HealthMeasurementData(icon: "drop.fill", title: "Blood glucose", value: value, date: longDateFormatter.string(from: bloodGlucose.date)))
        }

        return items
    }

    private func progress(_ value: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return min(max(value / goal, 0), 1)
    }

    private func formatNumber(_ value: Double, decimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = decimals
        formatter.minimumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    private func formatSigned(_ value: Double, decimals: Int) -> String {
        let sign = value > 0 ? "+" : value < 0 ? "-" : ""
        let formatted = formatNumber(abs(value), decimals: decimals)
        return "\(sign)\(formatted)"
    }

    private func formatHours(_ hours: Double) -> String {
        guard hours > 0 else { return "—" }
        let totalMinutes = Int(hours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "\(h)h \(m)m"
    }

    private var shortDateFormatter: Foundation.DateFormatter {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }

    private var longDateFormatter: Foundation.DateFormatter {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
