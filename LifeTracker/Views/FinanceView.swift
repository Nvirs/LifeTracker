import SwiftUI
import Charts
import SwiftData

enum FinanceTab: String, CaseIterable {
    case overview = "Overview"
    case transactions = "Transactions"
    case categories = "Categories"
    case goals = "Goals"

    var title: String { rawValue }
}

enum TransactionFilter: String, CaseIterable {
    case all = "All"
    case income = "Income"
    case expense = "Expense"
}

enum FinanceDateRange: String, CaseIterable {
    case thisMonth = "This Month"
    case last30Days = "Last 30 Days"
    case all = "All"

    var dateInterval: DateInterval? {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .thisMonth:
            guard let start = calendar.dateInterval(of: .month, for: now)?.start,
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else {
                return nil
            }
            return DateInterval(start: start, end: end)
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return DateInterval(start: start, end: now)
        case .all:
            return nil
        }
    }
}

enum BudgetPeriod: String, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"

    var dateInterval: DateInterval? {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: now)
        case .monthly:
            return calendar.dateInterval(of: .month, for: now)
        }
    }
}

struct FinanceView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    
    @State private var selectedTab: FinanceTab = .overview
    @State private var showingCalendar = false

    let onBack: () -> Void

    init(onBack: @escaping () -> Void = {}) {
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                }
                Spacer()
                Text("Finances")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button(action: {
                    showingCalendar = true
                }) {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            
            // Sub-navigation
            HStack(spacing: 20) {
                ForEach(FinanceTab.allCases, id: \.self) { tab in
                    FinanceSubTab(tab: tab, selectedTab: $selectedTab)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            Group {
                switch selectedTab {
                case .overview:
                    ScrollView {
                        FinanceOverviewTab(transactions: transactions, onSeeAll: {
                            withAnimation {
                                selectedTab = .transactions
                            }
                        })
                    }
                case .transactions:
                    FinanceTransactionsTab()
                case .categories:
                    ScrollView {
                        FinanceCategoriesTab()
                    }
                case .goals:
                    ScrollView {
                        FinanceGoalsTab()
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingCalendar) {
            FinanceSpendingCalendarView(transactions: transactions)
        }
    }
}

struct FinanceSubTab: View {
    let tab: FinanceTab
    @Binding var selectedTab: FinanceTab
    
    var body: some View {
        VStack(spacing: 6) {
            Text(tab.title)
                .font(.subheadline)
                .fontWeight(selectedTab == tab ? .bold : .regular)
                .foregroundColor(selectedTab == tab ? .blue : .gray)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
            
            Rectangle()
                .fill(selectedTab == tab ? Color.blue : Color.clear)
                .frame(height: 2)
        }
        .onTapGesture {
            withAnimation {
                selectedTab = tab
            }
        }
    }
}

struct FinanceOverviewTab: View {
    var transactions: [Transaction]
    let onSeeAll: () -> Void

    @State private var showingNewTransaction = false

    init(transactions: [Transaction], onSeeAll: @escaping () -> Void = {}) {
        self.transactions = transactions
        self.onSeeAll = onSeeAll
    }
    
    private var balance: Double {
        transactions.reduce(0) { $0 + ($1.isIncome ? $1.amount : -$1.amount) }
    }
    
    private var weeklyNetChange: Double {
        let startDate = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        return transactions
            .filter { $0.date >= startDate }
            .reduce(0) { $0 + ($1.isIncome ? $1.amount : -$1.amount) }
    }
    
    private var chartData: [FinanceDailyTotal] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let dayStart = calendar.startOfDay(for: day)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let total = transactions
                .filter { $0.date >= dayStart && $0.date < dayEnd }
                .reduce(0) { $0 + ($1.isIncome ? $1.amount : -$1.amount) }
            return FinanceDailyTotal(day: FinanceDateFormatter.shortWeekday.string(from: day), amount: total)
        }
    }
    
    private var chartDomain: ClosedRange<Double> {
        let values = chartData.map { $0.amount }
        let minValue = min(values.min() ?? 0, 0)
        let maxValue = max(values.max() ?? 0, 0)
        let padding = max(100, (maxValue - minValue) * 0.1)
        return (minValue - padding)...(maxValue + padding)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Main Balance Card
            VStack(alignment: .leading, spacing: 8) {
                Text("Balance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(FinanceCurrencyFormatter.string(balance))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text(FinanceCurrencyFormatter.signedString(weeklyNetChange))
                    .font(.subheadline)
                    .foregroundColor(weeklyNetChange >= 0 ? .green : .red)
                
                if transactions.isEmpty {
                    Text("No transactions yet")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                } else {
                    Chart {
                        ForEach(chartData) { item in
                            LineMark(
                                x: .value("Day", item.day),
                                y: .value("Amount", item.amount)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(.blue)
                            .symbol {
                                Circle()
                                    .strokeBorder(Color.blue, lineWidth: 2)
                                    .background(Circle().fill(Color.white))
                                    .frame(width: 8, height: 8)
                            }
                            
                            AreaMark(
                                x: .value("Day", item.day),
                                y: .value("Amount", item.amount)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(
                                colors: [.blue.opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                        }
                    }
                    .chartYScale(domain: chartDomain)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            if let unscaledValue = value.as(Double.self) {
                                AxisValueLabel {
                                    Text("\(Int(unscaledValue))")
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                    .padding(.top, 10)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            
            // Recent Transactions List
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("Recent transactions")
                        .font(.headline)
                    Spacer()
                    Button(action: onSeeAll) {
                        Text("See all")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                
                if transactions.isEmpty {
                    Text("No transactions yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(transactions.prefix(5)) { txn in
                        DetailedTransactionRow(
                            date: FinanceDateFormatter.shortMonthDay.string(from: txn.date),
                            icon: txn.isIncome ? "arrow.down.circle.fill" : "cart.fill",
                            iconColor: txn.isIncome ? .green : .blue,
                            name: txn.desc,
                            amount: FinanceCurrencyFormatter.signedString(txn.isIncome ? txn.amount : -txn.amount)
                        )
                    }
                }
                
                Button(action: {
                    showingNewTransaction = true
                }) {
                    HStack {
                        Text("New transaction")
                        Spacer()
                        Image(systemName: "plus")
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.top, 10)
            }
        }
        .padding()
        .sheet(isPresented: $showingNewTransaction) {
            TransactionEditorView(transaction: nil)
        }
    }
}

struct FinanceSpendingCalendarView: View {
    let transactions: [Transaction]

    @Environment(\.dismiss) private var dismiss
    @State private var monthOffset = 0

    private var calendar: Calendar { Calendar.current }

    private var baseMonthStart: Date {
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        return calendar.date(from: components) ?? now
    }

    private var displayMonthStart: Date {
        calendar.date(byAdding: .month, value: monthOffset, to: baseMonthStart) ?? baseMonthStart
    }

    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: displayMonthStart)
            ?? DateInterval(start: displayMonthStart, end: displayMonthStart)
    }

    private var monthTitle: String {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayMonthStart)
    }

    private var weekdaySymbols: [String] {
        var symbols = calendar.shortWeekdaySymbols
        let firstIndex = max(0, calendar.firstWeekday - 1)
        if firstIndex > 0 {
            let prefix = symbols.prefix(firstIndex)
            symbols.removeFirst(firstIndex)
            symbols.append(contentsOf: prefix)
        }
        return symbols
    }

    private var daysInMonth: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: displayMonthStart) else {
            return []
        }

        let weekdayIndex = calendar.component(.weekday, from: displayMonthStart)
        let leading = (weekdayIndex - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leading)

        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: displayMonthStart) {
                days.append(date)
            }
        }

        return days
    }

    private var dailyTotals: [Date: Double] {
        var totals: [Date: Double] = [:]

        for transaction in transactions where !transaction.isIncome {
            guard monthInterval.contains(transaction.date) else { continue }
            let dayStart = calendar.startOfDay(for: transaction.date)
            totals[dayStart, default: 0] += transaction.amount
        }

        return totals
    }

    private func shortCurrency(_ value: Double) -> String {
        String(format: "%.0f Ft", value)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Button(action: {
                        monthOffset -= 1
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    Text(monthTitle)
                        .font(.headline)

                    Spacer()

                    Button(action: {
                        monthOffset += 1
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.blue)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 10) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(daysInMonth.indices, id: \.self) { index in
                        let date = daysInMonth[index]
                        if let date {
                            let dayNumber = calendar.component(.day, from: date)
                            let dayStart = calendar.startOfDay(for: date)
                            let total = dailyTotals[dayStart] ?? 0
                            let isToday = calendar.isDateInToday(date)

                            VStack(spacing: 4) {
                                Text("\(dayNumber)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(isToday ? .blue : .primary)
                                Text(shortCurrency(total))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .opacity(total > 0 ? 1 : 0)
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                            )
                        } else {
                            Color.clear
                                .frame(minHeight: 48)
                        }
                    }
                }

                Text("Daily spending for the selected month")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer(minLength: 0)
            }
            .padding()
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Spending calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailedTransactionRow: View {
    let date: String
    let icon: String
    let iconColor: Color
    let name: String
    let amount: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(date)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Image(systemName: icon)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.15))
                .foregroundColor(iconColor)
                .cornerRadius(8)
            
            Text(name)
                .font(.headline)
            
            Spacer()
            
            Text(amount)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(amount.contains("+") ? .green : .primary)
        }
    }
}

struct FinanceTransactionsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    let dateRange: FinanceDateRange = .all

    @State private var filter: TransactionFilter = .all
    @State private var formState: TransactionFormState?

    private var filteredTransactions: [Transaction] {
        let rangeFiltered = transactions.filter { transaction in
            guard let interval = dateRange.dateInterval else { return true }
            return interval.contains(transaction.date)
        }

        switch filter {
        case .all:
            return rangeFiltered
        case .income:
            return rangeFiltered.filter { $0.isIncome }
        case .expense:
            return rangeFiltered.filter { !$0.isIncome }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("Filter", selection: $filter) {
                    ForEach(TransactionFilter.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Button(action: {
                    formState = TransactionFormState(transaction: nil)
                }) {
                    Label("New", systemImage: "plus")
                        .labelStyle(.iconOnly)
                        .frame(width: 36, height: 36)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .accessibilityLabel("New transaction")
            }
            .padding(.horizontal)
            .padding(.top, 10)

            if filteredTransactions.isEmpty {
                VStack(spacing: 8) {
                    Text("No transactions yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Add your first transaction to see it here.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
            } else {
                List {
                    ForEach(filteredTransactions) { txn in
                        Button(action: {
                            formState = TransactionFormState(transaction: txn)
                        }) {
                            TransactionListRow(transaction: txn)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Delete", role: .destructive) {
                                delete(txn)
                            }

                            Button("Edit") {
                                formState = TransactionFormState(transaction: txn)
                            }
                            .tint(.blue)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(item: $formState) { state in
            TransactionEditorView(transaction: state.transaction)
        }
    }

    private func delete(_ transaction: Transaction) {
        modelContext.delete(transaction)
        try? modelContext.save()
    }
}

struct TransactionListRow: View {
    let transaction: Transaction

    private var categoryName: String {
        transaction.category?.name ?? "Uncategorized"
    }

    private var categoryColor: Color {
        FinanceColor.color(from: transaction.category?.colorHex ?? FinanceColor.defaultCategoryHex)
    }

    private var categoryIcon: String {
        transaction.category?.icon ?? "questionmark.circle"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: categoryIcon)
                .frame(width: 32, height: 32)
                .background(categoryColor.opacity(0.15))
                .foregroundColor(categoryColor)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.desc.isEmpty ? "Untitled" : transaction.desc)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(categoryName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(FinanceCurrencyFormatter.signedString(transaction.isIncome ? transaction.amount : -transaction.amount))
                    .font(.subheadline)
                    .foregroundColor(transaction.isIncome ? .green : .primary)
                Text(FinanceDateFormatter.shortMonthDay.string(from: transaction.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TransactionFormState: Identifiable {
    let id = UUID()
    let transaction: Transaction?
}

struct FinanceCategoriesTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var selectedRange: FinanceDateRange = .thisMonth
    @State private var categoryFormState: CategoryFormState?

    private var filteredExpenses: [Transaction] {
        transactions.filter { transaction in
            guard !transaction.isIncome else { return false }
            guard let interval = selectedRange.dateInterval else { return true }
            return interval.contains(transaction.date)
        }
    }

    private var categorySummaries: [CategorySummary] {
        let grouped = Dictionary(grouping: filteredExpenses) { transaction in
            transaction.category?.id.uuidString ?? "uncategorized"
        }

        return grouped.compactMap { key, txns in
            let total = txns.reduce(0) { $0 + $1.amount }
            if let category = txns.first?.category {
                return CategorySummary(
                    id: category.id.uuidString,
                    name: category.name,
                    color: FinanceColor.color(from: category.colorHex),
                    amount: total
                )
            }

            return CategorySummary(
                id: key,
                name: "Uncategorized",
                color: FinanceColor.color(from: FinanceColor.defaultCategoryHex),
                amount: total
            )
        }
        .sorted { $0.amount > $1.amount }
    }

    private var totalSpent: Double {
        categorySummaries.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Picker("Range", selection: $selectedRange) {
                    ForEach(FinanceDateRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)
            .padding(.top)

            VStack(alignment: .leading, spacing: 16) {
                Text("Spending by category")
                    .font(.headline)

                if categorySummaries.isEmpty {
                    Text("No expenses for this period.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    if #available(iOS 17.0, *) {
                        Chart(categorySummaries) { item in
                            SectorMark(
                                angle: .value("Amount", item.amount),
                                innerRadius: .ratio(0.6)
                            )
                            .foregroundStyle(item.color)
                        }
                        .frame(height: 180)
                    } else {
                        Circle()
                            .strokeBorder(Color.blue.opacity(0.2), lineWidth: 22)
                            .frame(width: 160, height: 160)
                    }

                    VStack(spacing: 10) {
                        ForEach(categorySummaries) { item in
                            CategorySummaryRow(
                                color: item.color,
                                name: item.name,
                                percent: totalSpent == 0 ? 0 : item.amount / totalSpent,
                                amount: item.amount
                            )
                        }
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Categories")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        categoryFormState = CategoryFormState(category: nil)
                    }) {
                        Text("Add category")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }

                if categories.isEmpty {
                    Text("No categories yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(categories) { category in
                        Button(action: {
                            categoryFormState = CategoryFormState(category: category)
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: category.icon)
                                    .frame(width: 28, height: 28)
                                    .background(FinanceColor.color(from: category.colorHex).opacity(0.15))
                                    .foregroundColor(FinanceColor.color(from: category.colorHex))
                                    .cornerRadius(6)
                                Text(category.name)
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                delete(category)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .padding(.horizontal)
        }
        .padding(.bottom, 20)
        .sheet(item: $categoryFormState) { state in
            CategoryEditorView(category: state.category)
        }
    }

    private func delete(_ category: TransactionCategory) {
        modelContext.delete(category)
        try? modelContext.save()
    }
}

struct CategorySummary: Identifiable {
    let id: String
    let name: String
    let color: Color
    let amount: Double
}

struct CategorySummaryRow: View {
    let color: Color
    let name: String
    let percent: Double
    let amount: Double

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(name)
                .font(.caption)
                .foregroundColor(.primary)
                .frame(width: 110, alignment: .leading)
            Text("\(Int(percent * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(FinanceCurrencyFormatter.string(amount))
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

struct CategoryFormState: Identifiable {
    let id = UUID()
    let category: TransactionCategory?
}

struct CategoryEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let category: TransactionCategory?

    @State private var name: String
    @State private var icon: String
    @State private var colorHex: String

    private let iconOptions = [
        "cart.fill",
        "fork.knife",
        "house.fill",
        "car.fill",
        "creditcard.fill",
        "gift.fill",
        "gamecontroller.fill",
        "cross.case.fill",
        "bag.fill",
        "ellipsis.circle"
    ]

    private let colorOptions: [ColorOption] = [
        ColorOption(name: "Blue", hex: "#1E88E5", color: .blue),
        ColorOption(name: "Teal", hex: "#009688", color: .teal),
        ColorOption(name: "Green", hex: "#43A047", color: .green),
        ColorOption(name: "Orange", hex: "#FB8C00", color: .orange),
        ColorOption(name: "Pink", hex: "#E91E63", color: .pink),
        ColorOption(name: "Purple", hex: "#8E24AA", color: .purple),
        ColorOption(name: "Gray", hex: "#9E9E9E", color: .gray)
    ]

    init(category: TransactionCategory?) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _icon = State(initialValue: category?.icon ?? "cart.fill")
        _colorHex = State(initialValue: category?.colorHex ?? FinanceColor.defaultCategoryHex)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Name", text: $name)

                    Picker("Icon", selection: $icon) {
                        ForEach(iconOptions, id: \.self) { option in
                            Label(option, systemImage: option).tag(option)
                        }
                    }

                    Picker("Color", selection: $colorHex) {
                        ForEach(colorOptions) { option in
                            HStack {
                                Circle().fill(option.color).frame(width: 12, height: 12)
                                Text(option.name)
                            }
                            .tag(option.hex)
                        }
                    }
                }
            }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let category {
            category.name = trimmedName
            category.icon = icon
            category.colorHex = colorHex
        } else {
            let newCategory = TransactionCategory(
                name: trimmedName,
                icon: icon,
                colorHex: colorHex
            )
            modelContext.insert(newCategory)
        }

        try? modelContext.save()
        dismiss()
    }
}

struct ColorOption: Identifiable {
    let id: String
    let name: String
    let hex: String
    let color: Color

    init(name: String, hex: String, color: Color) {
        self.id = hex
        self.name = name
        self.hex = hex
        self.color = color
    }
}

struct FinanceGoalsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Budget.categoryName) private var budgets: [Budget]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]

    @State private var budgetFormState: BudgetFormState?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Budgets")
                    .font(.headline)
                Spacer()
                Button(action: {
                    budgetFormState = BudgetFormState(budget: nil)
                }) {
                    Text("Add budget")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)

            if budgets.isEmpty {
                Text("No budgets yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 30)
            } else {
                VStack(spacing: 12) {
                    ForEach(budgets) { budget in
                        let spent = spentAmount(for: budget)
                        BudgetProgressRow(
                            name: budget.categoryName,
                            current: spent,
                            max: budget.limitAmount,
                            color: categoryColor(for: budget.categoryName)
                        )
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                delete(budget)
                            }
                        }
                        .onTapGesture {
                            budgetFormState = BudgetFormState(budget: budget)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 20)
        .sheet(item: $budgetFormState) { state in
            BudgetEditorView(budget: state.budget, categories: categories)
        }
    }

    private func spentAmount(for budget: Budget) -> Double {
        let period = BudgetPeriod(rawValue: budget.period) ?? .monthly
        let interval = period.dateInterval

        return transactions.filter { transaction in
            guard !transaction.isIncome else { return false }
            if let interval {
                guard interval.contains(transaction.date) else { return false }
            }
            if budget.categoryName == "Uncategorized" {
                return transaction.category == nil
            }
            return transaction.category?.name == budget.categoryName
        }
        .reduce(0) { $0 + $1.amount }
    }

    private func categoryColor(for name: String) -> Color {
        if name == "Uncategorized" {
            return FinanceColor.color(from: FinanceColor.defaultCategoryHex)
        }
        return categories.first(where: { $0.name == name })
            .map { FinanceColor.color(from: $0.colorHex) } ?? .blue
    }

    private func delete(_ budget: Budget) {
        modelContext.delete(budget)
        try? modelContext.save()
    }
}

struct BudgetProgressRow: View {
    let name: String
    let current: Double
    let max: Double
    let color: Color

    private var progress: Double {
        guard max > 0 else { return 0 }
        return min(current / max, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.subheadline)
                Spacer()
                Text("\(FinanceCurrencyFormatter.string(current)) / \(FinanceCurrencyFormatter.string(max))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2)).frame(height: 6)
                    Capsule().fill(color)
                        .frame(width: geo.size.width * CGFloat(progress), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct BudgetFormState: Identifiable {
    let id = UUID()
    let budget: Budget?
}

struct BudgetEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let budget: Budget?
    private let categories: [TransactionCategory]

    @State private var selectedCategoryName: String
    @State private var limitAmount: Double
    @State private var period: BudgetPeriod

    init(budget: Budget?, categories: [TransactionCategory]) {
        self.budget = budget
        self.categories = categories
        let initialCategory = budget?.categoryName ?? (categories.isEmpty ? "" : "Uncategorized")
        _selectedCategoryName = State(initialValue: initialCategory)
        _limitAmount = State(initialValue: budget?.limitAmount ?? 0)
        _period = State(initialValue: BudgetPeriod(rawValue: budget?.period ?? "") ?? .monthly)
    }

    private var isValid: Bool {
        !selectedCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && limitAmount > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Category")) {
                    if categories.isEmpty {
                        TextField("Category name", text: $selectedCategoryName)
                    } else {
                        Picker("Category", selection: $selectedCategoryName) {
                            Text("Uncategorized").tag("Uncategorized")
                            ForEach(categories) { category in
                                Text(category.name).tag(category.name)
                            }
                        }
                    }
                }

                Section(header: Text("Limit")) {
                    TextField("Amount", value: $limitAmount, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                }

                Section(header: Text("Period")) {
                    Picker("Period", selection: $period) {
                        ForEach(BudgetPeriod.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(budget == nil ? "New Budget" : "Edit Budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let trimmedCategory = selectedCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCategory.isEmpty else { return }

        if let budget {
            budget.categoryName = trimmedCategory
            budget.limitAmount = limitAmount
            budget.period = period.rawValue
        } else {
            let newBudget = Budget(
                categoryName: trimmedCategory,
                limitAmount: limitAmount,
                period: period.rawValue
            )
            modelContext.insert(newBudget)
        }

        try? modelContext.save()
        dismiss()
    }
}

struct TransactionEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]

    private let transaction: Transaction?

    @State private var date: Date
    @State private var desc: String
    @State private var amount: Double
    @State private var isIncome: Bool
    @State private var selectedCategoryId: UUID?
    @State private var paymentMethod: String
    @State private var note: String
    @State private var tagsText: String

    init(transaction: Transaction?) {
        self.transaction = transaction
        _date = State(initialValue: transaction?.date ?? Date())
        _desc = State(initialValue: transaction?.desc ?? "")
        _amount = State(initialValue: abs(transaction?.amount ?? 0))
        _isIncome = State(initialValue: transaction?.isIncome ?? false)
        _selectedCategoryId = State(initialValue: transaction?.category?.id)
        _paymentMethod = State(initialValue: transaction?.paymentMethod ?? "")
        _note = State(initialValue: transaction?.note ?? "")
        _tagsText = State(initialValue: transaction?.tags.joined(separator: ", ") ?? "")
    }

    private var isValid: Bool {
        !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Description", text: $desc)
                }

                Section(header: Text("Amount")) {
                    Picker("Type", selection: $isIncome) {
                        Text("Expense").tag(false)
                        Text("Income").tag(true)
                    }
                    .pickerStyle(.segmented)

                    TextField("Amount", value: $amount, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                }

                Section(header: Text("Category")) {
                    Picker("Category", selection: $selectedCategoryId) {
                        Text("None").tag(UUID?.none)
                        ForEach(categories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                }

                Section(header: Text("More")) {
                    TextField("Payment method", text: $paymentMethod)
                    TextField("Note", text: $note)
                    TextField("Tags (comma separated)", text: $tagsText)
                }
            }
            .navigationTitle(transaction == nil ? "New Transaction" : "Edit Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let trimmedDesc = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDesc.isEmpty, amount > 0 else { return }

        let selectedCategory = categories.first { $0.id == selectedCategoryId }
        let parsedTags = tagsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let transaction {
            transaction.date = date
            transaction.desc = trimmedDesc
            transaction.amount = amount
            transaction.isIncome = isIncome
            transaction.category = selectedCategory
            transaction.paymentMethod = paymentMethod
            transaction.note = note
            transaction.tags = parsedTags
        } else {
            let newTransaction = Transaction(
                date: date,
                desc: trimmedDesc,
                amount: amount,
                isIncome: isIncome,
                category: selectedCategory,
                paymentMethod: paymentMethod,
                note: note,
                tags: parsedTags
            )
            modelContext.insert(newTransaction)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Helpers
struct FinanceDailyTotal: Identifiable {
    let id = UUID()
    let day: String
    let amount: Double
}

enum FinanceCurrencyFormatter {
    static func string(_ value: Double) -> String {
        String(format: "%.f Ft", value)
    }

    static func signedString(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return String(format: "%@%.f Ft", sign, abs(value))
    }
}

enum FinanceDateFormatter {
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

enum FinanceColor {
    static let defaultCategoryHex = "#9E9E9E"

    static func color(from hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var intValue: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&intValue)

        let a, r, g, b: UInt64
        switch cleaned.count {
        case 8:
            a = (intValue & 0xFF000000) >> 24
            r = (intValue & 0x00FF0000) >> 16
            g = (intValue & 0x0000FF00) >> 8
            b = intValue & 0x000000FF
        case 6:
            a = 255
            r = (intValue & 0xFF0000) >> 16
            g = (intValue & 0x00FF00) >> 8
            b = intValue & 0x0000FF
        default:
            a = 255
            r = 158
            g = 158
            b = 158
        }

        return Color(.sRGB,
                     red: Double(r) / 255,
                     green: Double(g) / 255,
                     blue: Double(b) / 255,
                     opacity: Double(a) / 255)
    }
}
