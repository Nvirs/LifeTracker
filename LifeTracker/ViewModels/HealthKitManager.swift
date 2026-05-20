import Foundation
import HealthKit

final class HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    private init() {}

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []

        if let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepCount)
        }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }
        if let bodyFat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.insert(bodyFat)
        }
        if let bmi = HKObjectType.quantityType(forIdentifier: .bodyMassIndex) {
            types.insert(bmi)
        }
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let bloodGlucose = HKObjectType.quantityType(forIdentifier: .bloodGlucose) {
            types.insert(bloodGlucose)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }

        types.insert(HKObjectType.workoutType())
        return types
    }

    func requestAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            store.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: success)
            }
        }
    }

    func fetchQuantitySum(for identifier: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return 0 }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
                let sum = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: sum)
            }
            store.execute(query)
        }
    }

    func fetchWorkoutCount(from start: Date, to end: Date) async -> Int {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: samples?.count ?? 0)
            }
            store.execute(query)
        }
    }

    func fetchSleepHours(from start: Date, to end: Date) async -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let asleepValues: Set<Int> = {
                    var values: [Int] = [HKCategoryValueSleepAnalysis.asleep.rawValue]
                    if #available(iOS 16.0, *) {
                        values.append(contentsOf: [
                            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                        ])
                    } else {
                        values.append(HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue)
                    }
                    return Set(values)
                }()

                let total = samples?.compactMap { $0 as? HKCategorySample }
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } ?? 0
                continuation.resume(returning: total / 3600.0)
            }
            store.execute(query)
        }
    }

    func fetchRecentQuantitySamples(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, limit: Int = 2) async -> [(value: Double, date: Date)] {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return [] }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: limit, sortDescriptors: [sort]) { _, samples, _ in
                let values = samples?.compactMap { $0 as? HKQuantitySample }
                    .map { (value: $0.quantity.doubleValue(for: unit), date: $0.endDate) } ?? []
                continuation.resume(returning: values)
            }
            store.execute(query)
        }
    }

    func fetchMostRecentQuantity(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> (value: Double, date: Date)? {
        let samples = await fetchRecentQuantitySamples(for: identifier, unit: unit, limit: 1)
        return samples.first
    }

    func fetchMostRecentBloodPressure() async -> (systolic: Double, diastolic: Double, date: Date)? {
        async let systolicSample = fetchMostRecentQuantity(for: .bloodPressureSystolic, unit: .millimeterOfMercury())
        async let diastolicSample = fetchMostRecentQuantity(for: .bloodPressureDiastolic, unit: .millimeterOfMercury())

        guard let systolic = await systolicSample,
              let diastolic = await diastolicSample else {
            return nil
        }

        let latestDate = max(systolic.date, diastolic.date)
        return (systolic: systolic.value, diastolic: diastolic.value, date: latestDate)
    }

    func fetchMostRecentHeartRate() async -> (value: Double, date: Date)? {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else { return nil }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { (continuation: CheckedContinuation<(value: Double, date: Date)?, Never>) in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: (value: value, date: sample.endDate))
            }
            store.execute(query)
        }
    }

    func fetchMostRecentBloodGlucose() async -> (value: Double, date: Date)? {
        guard let type = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else { return nil }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { (continuation: CheckedContinuation<(value: Double, date: Date)?, Never>) in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let unit = HKUnit(from: "mmol/L")
                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: (value: value, date: sample.endDate))
            }
            store.execute(query)
        }
    }
}

