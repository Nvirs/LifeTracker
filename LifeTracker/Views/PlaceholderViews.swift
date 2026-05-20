import SwiftUI
enum HealthTab: String, CaseIterable {
    case overview = "Overview"
    case steps = "Steps"
    case body = "Body"
    case measurements = "Measurements"

    var icon: String {
        switch self {
        case .overview: return "heart.text.square"
        case .steps: return "figure.walk"
        case .body: return "figure"
        case .measurements: return "ruler"
        }
    }
}

struct HealthView: View {
    @State private var selectedTab: HealthTab = .overview
    @StateObject private var viewModel = HealthViewModel()
    let onBack: (() -> Void)?

    init(onBack: (() -> Void)? = nil) {
        self.onBack = onBack
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HealthHeader(onBack: onBack)

                HealthTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                ScrollView {
                    VStack(spacing: 16) {
                        if viewModel.authorizationState != .authorized {
                            HealthAccessCard(state: viewModel.authorizationState) {
                                Task {
                                    await viewModel.requestAccessAndLoad()
                                }
                            }
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }

                        if viewModel.isLoading {
                            ProgressView("Syncing Health data...")
                                .padding(.vertical, 8)
                        }

                        switch selectedTab {
                        case .overview:
                            HealthOverviewSection(summaryCards: viewModel.summaryCards, bodyStats: viewModel.bodyStats, photoItems: viewModel.photoItems, measurements: viewModel.measurements)
                        case .steps:
                            HealthStepsDetailSection(stepsValue: viewModel.stepsValue, stepsText: viewModel.stepsValueText, caloriesValue: viewModel.activeCaloriesValue)
                        case .body:
                            HealthBodySection(bodyStats: viewModel.bodyStats, photoItems: viewModel.photoItems)
                        case .measurements:
                            HealthMeasurementsSection(measurements: viewModel.measurements)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .background(Color(uiColor: .systemGroupedBackground))
            }
            .navigationBarHidden(true)
        }
        .task {
            await viewModel.requestAccessAndLoad()
        }
    }
}

struct HealthHeader: View {
    @Environment(\.dismiss) private var dismiss
    let onBack: (() -> Void)?

    var body: some View {
        HStack {
            Button(action: {
                if let onBack {
                    onBack()
                } else {
                    dismiss()
                }
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.primary)
            }

            Spacer()

            Text("Health")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Spacer()

            Color.clear
                .frame(width: 24, height: 24)
        }
        .padding()
    }
}

struct HealthTabBar: View {
    @Binding var selectedTab: HealthTab

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(HealthTab.allCases, id: \.self) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        VStack(spacing: 6) {
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(selectedTab == tab ? .bold : .regular)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundColor(selectedTab == tab ? .green : .secondary)
                        .frame(minWidth: 72)
                        .padding(.vertical, 6)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(selectedTab == tab ? Color.green : Color.clear)
                                .frame(height: 2)
                                .padding(.top, 4)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
        }
    }
}

struct HealthOverviewSection: View {
    let summaryCards: [HealthSummaryCardData]
    let bodyStats: [HealthBodyStatData]
    let photoItems: [HealthPhotoData]
    let measurements: [HealthMeasurementData]

    private let summaryColumns = [GridItem(.adaptive(minimum: 80), spacing: 10)]

    var body: some View {
        VStack(spacing: 16) {
            HealthSectionHeader(title: "Daily overview", subtitle: "Synced with Apple Health")

            if summaryCards.isEmpty {
                HealthEmptyState(text: "No Health data yet.")
            } else {
                LazyVGrid(columns: summaryColumns, spacing: 10) {
                    ForEach(summaryCards) { card in
                        HealthSummaryCard(data: card)
                    }
                }

                HealthBodySection(bodyStats: bodyStats, photoItems: photoItems)
                HealthMeasurementsSection(measurements: measurements)
                HealthPrimaryButton(title: "Add entry")
            }
        }
    }
}

struct HealthMetricDetailSection: View {
    let title: String
    let value: String
    let goal: String
    let color: Color
    let entries: [HealthDailyEntry]

    var body: some View {
        VStack(spacing: 16) {
            HealthSectionHeader(title: title, subtitle: "Synced with Apple Health")

            VStack(alignment: .leading, spacing: 12) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                Text(goal)
                    .font(.caption)
                    .foregroundColor(.secondary)

                ProgressView(value: entries.first?.progress ?? 0)
                    .tint(color)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)

            if entries.isEmpty {
                HealthEmptyState(text: "No entries yet.")
            } else {
                VStack(spacing: 12) {
                    ForEach(entries) { entry in
                        HealthDailyEntryRow(entry: entry, color: color)
                    }
                }

                HealthPrimaryButton(title: "Add entry")
            }
        }
    }
}

enum HealthStepsRange: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
}

struct HealthStepsDetailSection: View {
    let stepsValue: Double
    let stepsText: String
    let caloriesValue: Double

    @State private var range: HealthStepsRange = .day
    @State private var selectedDate = Date()

    private let stepsGoal = 10000.0
    private let stepsPerKm = 1250.0
    private let stepsPerMinute = 100.0

    private var progress: Double {
        guard stepsGoal > 0 else { return 0 }
        return min(max(stepsValue / stepsGoal, 0), 1)
    }

    private var distanceText: String {
        let km = stepsValue / stepsPerKm
        return String(format: "%.1f km", km)
    }

    private var caloriesText: String {
        String(format: "%.0f kcal", caloriesValue)
    }

    private var durationText: String {
        let minutes = max(Int(stepsValue / stepsPerMinute), 0)
        let hours = minutes / 60
        let remaining = minutes % 60
        if hours > 0 {
            return "\(hours)h \(remaining)m"
        }
        return "\(remaining)m"
    }

    private var displayDateText: String {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: selectedDate)
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("Range", selection: $range) {
                ForEach(HealthStepsRange.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button(action: {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.green)
                }

                Spacer()

                Text(displayDateText)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.green)
                }
            }

            HStack(spacing: 20) {
                HealthStepsRingView(stepsText: stepsText, progress: progress)
                    .frame(width: 160, height: 160)

                VStack(alignment: .leading, spacing: 12) {
                    HealthStepsStatRow(title: "Distance", value: distanceText)
                    HealthStepsStatRow(title: "Calories", value: caloriesText)
                    HealthStepsStatRow(title: "Duration", value: durationText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(18)

            HealthStepsBarChart(stepsValue: stepsValue)
                .padding()
                .background(Color.white)
                .cornerRadius(18)

            HStack(spacing: 12) {
                HealthStepsSummaryCard(title: "Average (7 days)", value: stepsText)
                HealthStepsSummaryCard(title: "Goal", value: "10,000 steps")
            }
        }
    }
}

struct HealthStepsRingView: View {
    let stepsText: String
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.green.opacity(0.15), lineWidth: 14)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 6) {
                Text(stepsText)
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Steps")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
    }
}

struct HealthStepsStatRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

struct HealthStepsBarChart: View {
    let stepsValue: Double

    private let pattern: [Double] = [
        0.02, 0.02, 0.04, 0.08, 0.12, 0.1,
        0.06, 0.05, 0.06, 0.1, 0.15, 0.2
    ]

    private var buckets: [Double] {
        let total = pattern.reduce(0, +)
        return pattern.map { stepsValue * ($0 / total) }
    }

    private var maxBucket: Double {
        max(buckets.max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(buckets.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.green.opacity(0.8))
                        .frame(height: CGFloat(buckets[index] / maxBucket) * 80)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .bottom)

            HStack {
                Text("00")
                Spacer()
                Text("06")
                Spacer()
                Text("12")
                Spacer()
                Text("18")
                Spacer()
                Text("24")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
    }
}

struct HealthStepsSummaryCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(14)
    }
}

struct HealthBodySection: View {
    let bodyStats: [HealthBodyStatData]
    let photoItems: [HealthPhotoData]

    var body: some View {
        VStack(spacing: 16) {
            HealthSectionHeader(title: "Body status", subtitle: nil)

            if bodyStats.isEmpty {
                HealthEmptyState(text: "No body metrics yet.")
            } else {
                HealthBodySummaryCard(stats: bodyStats)
            }

            HealthSectionHeader(title: "Body photos", subtitle: nil)

            if photoItems.isEmpty {
                HealthEmptyState(text: "No photos yet.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(photoItems) { item in
                            HealthPhotoCard(item: item)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }
}

struct HealthBodySummaryCard: View {
    let stats: [HealthBodyStatData]

    private var displayStats: [HealthBodyStatData] {
        Array(stats.prefix(3))
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(displayStats.indices, id: \.self) { index in
                let stat = displayStats[index]
                HealthBodyStatColumn(stat: stat)

                if index < displayStats.count - 1 {
                    Divider()
                        .background(Color.gray.opacity(0.3))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(16)
    }
}

struct HealthBodyStatColumn: View {
    let stat: HealthBodyStatData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stat.title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(stat.value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(stat.delta)
                .font(.caption2)
                .foregroundColor(stat.deltaColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HealthMeasurementsSection: View {
    let measurements: [HealthMeasurementData]

    var body: some View {
        VStack(spacing: 12) {
            HealthSectionHeader(title: "Latest measurements", subtitle: nil)

            if measurements.isEmpty {
                HealthEmptyState(text: "No measurements yet.")
            } else {
                VStack(spacing: 12) {
                    ForEach(measurements) { measurement in
                        HealthMeasurementRow(measurement: measurement)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16)
            }
        }
    }
}

struct HealthAccessCard: View {
    let state: HealthAuthorizationState
    let action: () -> Void

    private var title: String {
        switch state {
        case .unknown:
            return "Connect Apple Health"
        case .unauthorized:
            return "Health access needed"
        case .authorized:
            return "Health connected"
        }
    }

    private var message: String {
        switch state {
        case .unknown:
            return "Enable Health access to sync your daily stats."
        case .unauthorized:
            return "Allow Health access in Settings to see your data here."
        case .authorized:
            return "Health data is synced."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)

            if state != .authorized {
                Button(action: action) {
                    Text("Enable Health Access")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(14)
    }
}

struct HealthEmptyState: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.white)
            .cornerRadius(14)
    }
}

struct HealthSectionHeader: View {
    let title: String
    let subtitle: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
    }
}

struct HealthSummaryCardData: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let goal: String
    let progress: Double
    let color: Color
}

struct HealthSummaryCard: View {
    let data: HealthSummaryCardData

    private var clampedProgress: Double {
        min(max(data.progress, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(data.title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(data.value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(data.goal)
                .font(.caption2)
                .foregroundColor(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    Capsule()
                        .fill(data.color)
                        .frame(width: geo.size.width * clampedProgress, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct HealthBodyStatData: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let delta: String
    let deltaColor: Color
}

struct HealthBodyStatRow: View {
    let stat: HealthBodyStatData

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(stat.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(stat.value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(stat.delta)
                    .font(.caption2)
                    .foregroundColor(stat.deltaColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HealthMeasurementData: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let value: String
    let date: String
}

struct HealthMeasurementRow: View {
    let measurement: HealthMeasurementData

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: measurement.icon)
                .frame(width: 28, height: 28)
                .foregroundColor(.green)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(measurement.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(measurement.value)
                    .font(.subheadline)
            }

            Spacer()

            Text(measurement.date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct HealthPhotoData: Identifiable {
    let id = UUID()
    let title: String
}

struct HealthPhotoCard: View {
    let item: HealthPhotoData

    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [Color.green.opacity(0.15), Color.green.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                .frame(width: 92, height: 96)
                .overlay(
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(.green)
                )
            Text(item.title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 92)
        .padding(8)
        .background(Color.white)
        .cornerRadius(14)
    }
}

struct HealthDailyEntry: Identifiable {
    let id = UUID()
    let date: String
    let value: String
    let progress: Double
}

struct HealthDailyEntryRow: View {
    let entry: HealthDailyEntry
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.date)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 64, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                ProgressView(value: entry.progress)
                    .tint(color)
            }

            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(14)
    }
}

struct HealthPrimaryButton: View {
    let title: String

    var body: some View {
        Button(action: {}) {
            HStack {
                Text(title)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "plus")
                    .font(.headline)
            }
            .padding()
            .foregroundColor(.white)
            .background(Color.green)
            .cornerRadius(16)
        }
    }
}


