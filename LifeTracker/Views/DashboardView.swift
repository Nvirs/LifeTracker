import SwiftUI
import Charts
import SwiftData

struct DashboardView: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Custom Header
                        HStack {
                            Text("LifeTracker")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 36, height: 36)
                                .foregroundColor(.gray)
                            
                            Button(action: {}) {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        // Cards
                        FinancesCard(onDetailsTap: {
                            selectedTab = .finances
                        })
                        HealthCard(onDetailsTap: {
                            selectedTab = .health
                        })
                        PersonalLifeCard(onDetailsTap: {
                            selectedTab = .personal
                        })
                        TravelCard()
                        NotesCard(onDetailsTap: {
                            selectedTab = .notes
                        })
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Reusable Card Style
struct DashboardCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(20)
            .padding(.horizontal)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

extension View {
    func dashboardCardStyle() -> some View {
        self.modifier(DashboardCardStyle())
    }
}

// MARK: - Generic Header for Cards
struct CardHeader: View {
    let icon: String
    let title: String
    let color: Color
    let detailsAction: (() -> Void)?

    init(icon: String, title: String, color: Color, detailsAction: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.color = color
        self.detailsAction = detailsAction
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.subheadline)
                .foregroundColor(color)
                .bold()
            
            Spacer()
            
            if let detailsAction {
                Button(action: detailsAction) {
                    HStack(spacing: 4) {
                        Text("Details")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption)
                    .foregroundColor(color.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 8)
    }
}

// MARK: - 1. Finances Card
struct FinancesCard: View {
    var onDetailsTap: (() -> Void)? = nil
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    
    private var balance: Double {
        transactions.reduce(0) { $0 + ($1.isIncome ? $1.amount : -$1.amount) }
    }
    
    private var weeklyNetChange: Double {
        let startDate = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        return transactions
            .filter { $0.date >= startDate }
            .reduce(0) { $0 + ($1.isIncome ? $1.amount : -$1.amount) }
    }
    
    private var recentTransactions: [Transaction] {
        Array(transactions.prefix(3))
    }
    
    private var weeklyTotals: [DailyTotal] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let dayStart = calendar.startOfDay(for: day)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let total = transactions
                .filter { $0.date >= dayStart && $0.date < dayEnd }
                .reduce(0) { $0 + ($1.isIncome ? $1.amount : -$1.amount) }
            let label = DateFormatter.shortWeekday.string(from: day)
            return DailyTotal(day: label, amount: total)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardHeader(icon: "creditcard.fill", title: "Finances", color: .blue, detailsAction: onDetailsTap)
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Balance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(CurrencyFormatter.string(balance))
                        .font(.title2)
                        .bold()
                    Text(CurrencyFormatter.signedString(weeklyNetChange))
                        .font(.caption)
                        .foregroundColor(weeklyNetChange >= 0 ? .green : .red)
                    
                    if transactions.isEmpty {
                        Text("No transactions yet")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                    } else {
                        HStack(alignment: .bottom, spacing: 4) {
                            let maxValue = max(weeklyTotals.map { abs($0.amount) }.max() ?? 1, 1)
                            ForEach(weeklyTotals) { item in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.blue.opacity(0.8))
                                    .frame(width: 6, height: CGFloat(abs(item.amount) / maxValue) * 40)
                            }
                        }
                        .frame(height: 40, alignment: .bottom)
                        .padding(.top, 10)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Transactions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if recentTransactions.isEmpty {
                        Text("No transactions yet")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(recentTransactions) { txn in
                                TransactionRow(
                                    date: DateFormatter.shortMonthDay.string(from: txn.date),
                                    name: txn.desc,
                                    amount: CurrencyFormatter.signedString(txn.isIncome ? txn.amount : -txn.amount),
                                    isIncome: txn.isIncome
                                )
                            }
                        }
                    }
                }
            }
        }
        .dashboardCardStyle()
    }
}

struct TransactionRow: View {
    let date: String
    let name: String
    let amount: String
    let isIncome: Bool
    
    var body: some View {
        HStack {
            Text(date)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 42, alignment: .leading)
            Text(name)
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 10)
            Text(amount)
                .font(.caption)
                .foregroundColor(isIncome ? .green : .red)
        }
    }
}

// MARK: - 2. Health Card
struct HealthCard: View {
    var onDetailsTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardHeader(icon: "heart.fill", title: "Health", color: .green, detailsAction: onDetailsTap)

            HStack(spacing: 12) {
                HealthCompactStat(title: "Steps", value: "8 642", subtitle: "of 10,000", icon: "figure.walk", color: .green)
                HealthCompactStat(title: "Sleep", value: "7h 23m", subtitle: "goal 8h", icon: "moon.fill", color: .indigo)
            }
            .padding(12)
            .background(Color.green.opacity(0.08))
            .cornerRadius(14)
        }
        .dashboardCardStyle()
    }
}

struct HealthCompactStat: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 3. Personal Life Card
struct PersonalLifeCard: View {
    var onDetailsTap: (() -> Void)? = nil
    @Query(sort: \Habit.title) private var habits: [Habit]
    @Query(sort: \MoodEntry.date, order: .reverse) private var moods: [MoodEntry]
    @Query(sort: \PersonalGoal.title) private var goals: [PersonalGoal]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardHeader(icon: "person.2.fill", title: "Personal Life", color: .purple, detailsAction: onDetailsTap)
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Habits")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if habits.isEmpty {
                        Text("No habits yet")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(habits.prefix(4)) { habit in
                            HabitRow(title: habit.title, isDone: habit.isCompletedToday)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mood")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if let latestMood = moods.first {
                            HStack(spacing: 6) {
                                Image(systemName: MoodIcon.symbol(for: latestMood.rating))
                                    .foregroundColor(MoodIcon.color(for: latestMood.rating))
                                Text(MoodIcon.label(for: latestMood.rating))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("No mood yet")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Goal")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if let goal = goals.first {
                            let progress = max(0, min(Double(goal.currentCount) / Double(max(goal.targetCount, 1)), 1))
                            Text("\(goal.title)")
                                .font(.caption)
                                .bold()
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.gray.opacity(0.2))
                                        .frame(height: 6)
                                    Capsule().fill(Color.purple)
                                        .frame(width: geo.size.width * progress, height: 6)
                                }
                            }
                            .frame(height: 6)
                            
                            Text("\(goal.currentCount) / \(goal.targetCount)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No goals yet")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .dashboardCardStyle()
    }
}

struct HabitRow: View {
    let title: String
    let isDone: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isDone ? "checkmark.square.fill" : "square")
                .foregroundColor(isDone ? .green : .gray)
                .font(.caption)
            Text(title)
                .font(.caption)
                .strikethrough(isDone, color: .gray)
                .foregroundColor(isDone ? .gray : .primary)
        }
    }
}

// MARK: - 4. Travel Card
struct TravelCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardHeader(icon: "airplane", title: "Travel", color: .orange)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Latest Destination")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Vienna, Austria")
                        .font(.subheadline)
                        .bold()
                    Text("May 10-12, 2024")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 60)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                
                // Mock Map
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
                    .frame(height: 120)
                    .overlay(
                        ZStack {
                            Image(systemName: "map")
                                .resizable()
                                .scaledToFit()
                                .padding()
                                .foregroundColor(.blue.opacity(0.2))
                            
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.red)
                                .offset(x: -10, y: -10)
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.orange)
                                .offset(x: 20, y: 10)
                        }
                    )
            }
        }
        .dashboardCardStyle()
    }
}

// MARK: - 5. Notes Card
struct NotesCard: View {
    var onDetailsTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardHeader(icon: "doc.text.fill", title: "Notes", color: .pink, detailsAction: onDetailsTap)
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent Notes")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    NoteRow(color: .pink, title: "Project Ideas", date: "05.18")
                    NoteRow(color: .orange, title: "Vacation Plans", date: "05.17")
                    NoteRow(color: .red, title: "Book Ideas", date: "05.16")
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("To-Dos")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    TodoRow(title: "Finish Report", isDone: false)
                    TodoRow(title: "Workout", isDone: true)
                    TodoRow(title: "Go to Post Office", isDone: false)
                }
            }
        }
        .dashboardCardStyle()
    }
}

struct NoteRow: View {
    let color: Color
    let title: String
    let date: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text.fill")
                .foregroundColor(color)
                .font(.caption2)
            Text(title)
                .font(.caption)
            Spacer()
            Text(date)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct TodoRow: View {
    let title: String
    let isDone: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isDone ? "checkmark.square.fill" : "square")
                .foregroundColor(isDone ? .green : .gray)
                .font(.caption)
            Text(title)
                .font(.caption)
                .strikethrough(isDone, color: .gray)
                .foregroundColor(isDone ? .gray : .primary)
        }
    }
}

// MARK: - Helpers
struct DailyTotal: Identifiable {
    let id = UUID()
    let day: String
    let amount: Double
}

enum CurrencyFormatter {
    static func string(_ value: Double) -> String {
        String(format: " %.f Ft", value)
    }

    static func signedString(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return String(format: "%@  %.f Ft", sign, abs(value))
    }
}

enum MoodIcon {
    static func symbol(for rating: Int) -> String {
        switch rating {
        case 5: return "face.smiling.fill"
        case 4: return "face.smiling"
        case 3: return "face.neutral"
        case 2: return "face.frowning"
        default: return "face.dashed"
        }
    }

    static func color(for rating: Int) -> Color {
        switch rating {
        case 5: return .green
        case 4: return .teal
        case 3: return .yellow
        case 2: return .orange
        default: return .gray
        }
    }

    static func label(for rating: Int) -> String {
        switch rating {
        case 5: return "Great"
        case 4: return "Good"
        case 3: return "Okay"
        case 2: return "Low"
        default: return "No data"
        }
    }
}

enum DateFormatter {
    static let shortWeekday: Foundation.DateFormatter = {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()

    static let shortMonthDay: Foundation.DateFormatter = {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = "MM.dd"
        return formatter
    }()
}
