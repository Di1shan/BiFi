import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers

// MARK: - Dashboard View
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @Query private var categories: [Category]
    @Query private var settings: [AppSettings]
    @Query private var budgets: [BudgetMonth]
    
    @State private var selectedDate: Date = Date()
    @State private var showAddIncome = false
    @State private var showAddExpense = false
    @State private var currencyFilter: CurrencyFilter = .primary
    @State private var showAllInsights = false
    
    // Widget Order State
    @State private var widgetOrder: [String] = []
    @State private var draggedWidget: String?
    
    private var currentSettings: AppSettings? {
        settings.first
    }
    
    private var primaryCode: String {
        currentSettings?.primaryCurrencyCode ?? "LKR"
    }
    
    private var secondaryCode: String {
        currentSettings?.secondaryCurrencyCode ?? "AUD"
    }
    
    private var currentPeriod: (start: Date, endExclusive: Date, displayEnd: Date, key: String, title: String, rangeDescription: String) {
        FinancialMonthHelper.financialPeriod(
            containing: selectedDate,
            startDay: currentSettings?.effectiveFinancialStartDay ?? 1
        )
    }
    
    private var selectedMonthKey: String {
        currentPeriod.key
    }
    
    // Default Widgets
    private let defaultWidgetOrder = [
        "quickActions", "savingsRate", "budgetActual", "insights", "categoryPie",
        "dailySpending", "trendChart", "suggestions", "monthSummary"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Custom Header
                    HStack {
                        Text("Dashboard")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    
                    monthSelector
                    
                    // Fixed Top Section
                    currentInHandSection
                    
                    // Draggable Widgets
                    LazyVStack(spacing: 20) {
                        ForEach(widgetOrder, id: \.self) { widget in
                            view(for: widget)
                                .onDrag {
                                    self.draggedWidget = widget
                                    return NSItemProvider(object: widget as NSString)
                                }
                                .onDrop(of: [.text], delegate: WidgetDropDelegate(item: widget, items: $widgetOrder, draggedItem: $draggedWidget, onSave: saveOrder))
                        }
                    }
                    
                    // Bottom Padding
                    Color.clear.frame(height: 60)
                }
                .padding()
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: widgetOrder)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddIncome) {
                AddEditTransactionView(prefillType: .income)
            }
            .sheet(isPresented: $showAddExpense) {
                AddEditTransactionView(prefillType: .expense)
            }
            .onAppear {
                loadOrder()
            }
        }
    }
    
    private func saveOrder() {
        if let setting = currentSettings {
            setting.dashboardWidgetOrder = widgetOrder
            try? modelContext.save()
        }
    }
    
    private func loadOrder() {
        if let setting = currentSettings, !setting.dashboardWidgetOrder.isEmpty {
            // Verify all defaults are present (migration support)
            var loaded = setting.dashboardWidgetOrder
            for def in defaultWidgetOrder {
                if !loaded.contains(def) {
                    loaded.append(def)
                }
            }
            widgetOrder = loaded
        } else {
            widgetOrder = defaultWidgetOrder
        }
    }
    
    @ViewBuilder
    private func view(for widget: String) -> some View {
        switch widget {
        case "quickActions": quickActionsSection
        case "savingsRate": savingsRateSection
        case "budgetActual": budgetActualSection
        case "insights": insightsSection
        case "categoryPie": categoryPieChartSection
        case "dailySpending": dailySpendingSection
        case "trendChart": trendChartSection
        case "suggestions": suggestionsSection
        case "monthSummary": monthSummarySection
        default: EmptyView()
        }
    }
    
    // MARK: - Month Selector
    private var monthSelector: some View {
        HStack {
            Button {
                HapticsHelper.shared.impact(.light)
                selectedDate = FinancialMonthHelper.shiftFinancialAnchor(
                    selectedDate,
                    by: -1,
                    startDay: currentSettings?.effectiveFinancialStartDay ?? 1
                )
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            Text(currentPeriod.title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button {
                HapticsHelper.shared.impact(.light)
                selectedDate = FinancialMonthHelper.shiftFinancialAnchor(
                    selectedDate,
                    by: 1,
                    startDay: currentSettings?.effectiveFinancialStartDay ?? 1
                )
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .animatedCard(delay: 0)
    }
    
    // MARK: - Current In-Hand (Fixed)
    private var currentInHandSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current In-Hand")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                inHandCard(
                    title: primaryCode,
                    amount: BalanceCalculator.currentInHand(transactions: transactions, currency: .primary),
                    currencyCode: primaryCode,
                    gradient: AppTheme.cardGradient1
                )
                
                inHandCard(
                    title: secondaryCode,
                    amount: BalanceCalculator.currentInHand(transactions: transactions, currency: .secondary),
                    currencyCode: secondaryCode,
                    gradient: AppTheme.cardGradient2
                )
            }
        }
    }
    
    private func inHandCard(title: String, amount: Decimal, currencyCode: String, gradient: LinearGradient) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Text(MoneyFormatter.format(amount, currencyCode: currencyCode))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 100)
        .padding()
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        HStack(spacing: 16) {
            Button {
                HapticsHelper.shared.impact()
                showAddIncome = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Add Income")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(.white)
                .background(AppTheme.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: AppTheme.accentPurple.opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(BounceButtonStyle())
            
            Button {
                HapticsHelper.shared.impact()
                showAddExpense = true
            } label: {
                HStack {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                    Text("Add Expense")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(.white)
                .background(AppTheme.expenseGradient)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: AppTheme.accentOrange.opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(BounceButtonStyle())
        }
    }
    
    // MARK: - Savings Rate
    private var savingsRateSection: some View {
        let currency: CurrencyType = currencyFilter == .secondary ? .secondary : .primary
        let code = currencyFilter == .secondary ? secondaryCode : primaryCode
        
        let income = BalanceCalculator.calculateTotal(transactions: monthlyTransactions, type: .income, currency: currency)
        let expense = BalanceCalculator.calculateTotal(transactions: monthlyTransactions, type: .expense, currency: currency)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This Month")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Picker("Currency", selection: $currencyFilter) {
                    Text(primaryCode).tag(CurrencyFilter.primary)
                    Text(secondaryCode).tag(CurrencyFilter.secondary)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
            
            SavingsRateGauge(income: income, expense: expense, currencyCode: code)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Performance Optimization
    // Filter transactions for the selected month ONCE
    // MARK: - Performance Optimization
    // Filter transactions for the selected month ONCE
    private var monthlyTransactions: [Transaction] {
        let period = currentPeriod
        return transactions.filter {
            $0.date >= period.start && $0.date < period.endExclusive
        }
    }
    
    // MARK: - Budget vs Actual
    private var budgetActualSection: some View {
        let currentBudget = budgets.first { $0.monthKey == selectedMonthKey }
        
        // Use optimized calculation on pre-filtered list
        let primaryExpense = BalanceCalculator.calculateTotal(
            transactions: monthlyTransactions,
            type: .expense,
            currency: .primary
        )
        let secondaryExpense = BalanceCalculator.calculateTotal(
            transactions: monthlyTransactions,
            type: .expense,
            currency: .secondary
        )
        
        return BudgetActualChart(
            primaryBudget: currentBudget?.primaryMonthlyBudget ?? 0,
            primaryActual: primaryExpense,
            secondaryBudget: currentBudget?.secondaryMonthlyBudget ?? 0,
            secondaryActual: secondaryExpense,
            primaryCode: primaryCode,
            secondaryCode: secondaryCode
        )
    }
    
    // MARK: - Insights
    private var insightsSection: some View {
        let insights = InsightsGenerator.generateInsights(
            transactions: transactions,
            categories: categories,
            budgets: budgets,
            monthKey: selectedMonthKey,
            periodStart: currentPeriod.start,
            periodEndExclusive: currentPeriod.endExclusive,
            startDay: currentSettings?.effectiveFinancialStartDay ?? 1,
            primaryCode: primaryCode,
            secondaryCode: secondaryCode
        )
        
        return Group {
            if !insights.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Insights")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if insights.count > 2 {
                            Button {
                                withAnimation {
                                    showAllInsights.toggle()
                                }
                            } label: {
                                Text(showAllInsights ? "Show Less" : "Show All (\(insights.count))")
                                    .font(.caption)
                            }
                            .buttonStyle(BounceButtonStyle())
                        }
                    }
                    
                    let displayInsights = showAllInsights ? insights : Array(insights.prefix(2))
                    
                    ForEach(displayInsights, id: \.id) { insight in
                        InsightCard(insight: insight)
                    }
                }
            }
        }
    }
    
    // MARK: - Charts
    private var categoryPieChartSection: some View {
        let currency: CurrencyType = currencyFilter == .secondary ? .secondary : .primary
        let code = currencyFilter == .secondary ? secondaryCode : primaryCode
        
        let breakdown = BalanceCalculator.categoryBreakdown(
            transactions: monthlyTransactions, // Pass filtered list
            categories: categories,
            currency: currency
            // No monthKey passed, so it calculates on the already-filtered list
        )
        
        let chartData = breakdown.map { item in
            SpendingChartData(
                category: item.category?.name ?? "Uncategorized",
                amount: item.amount,
                color: Color(hex: item.category?.colorHex ?? "#808080"),
                percentage: item.percentage
            )
        }
        
        return CategoryPieChart(data: chartData, currencyCode: code)
    }
    
    private var dailySpendingSection: some View {
        let currency: CurrencyType = currencyFilter == .secondary ? .secondary : .primary
        let code = currencyFilter == .secondary ? secondaryCode : primaryCode
        let data = getDailySpendingData(currency: currency)
        
        return DailySpendingChart(data: data, currencyCode: code)
    }
    
    private func getDailySpendingData(currency: CurrencyType) -> [DailySpendingData] {
        let calendar = Calendar.current
        let today = Date()
        var data: [DailySpendingData] = []
        
        for i in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            
            let dayTransactions = transactions.filter { tx in
                tx.currency == currency &&
                tx.type == .expense &&
                tx.date >= dayStart &&
                tx.date < dayEnd
            }
            
            let total = dayTransactions.reduce(Decimal.zero) { $0 + $1.amount }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            let dayLabel = formatter.string(from: date)
            
            data.append(DailySpendingData(date: date, amount: total, dayLabel: dayLabel))
        }
        
        return data
    }
    
    private var trendChartSection: some View {
        let currency: CurrencyType = currencyFilter == .secondary ? .secondary : .primary
        let code = currencyFilter == .secondary ? secondaryCode : primaryCode
        let data = getTrendData(currency: currency)
        
        return TrendChart(data: data, currencyCode: code)
    }
    
    private func getTrendData(currency: CurrencyType) -> [TrendData] {
        var data: [TrendData] = []
        var currentDate = selectedDate
        let startDay = currentSettings?.effectiveFinancialStartDay ?? 1
        
        // Get last 4 months including current
        for _ in 0..<4 {
            let period = FinancialMonthHelper.financialPeriod(containing: currentDate, startDay: startDay)
            
            let income = BalanceCalculator.periodIncome(transactions: transactions, currency: currency, start: period.start, endExclusive: period.endExclusive)
            let expense = BalanceCalculator.periodExpense(transactions: transactions, currency: currency, start: period.start, endExclusive: period.endExclusive)
            
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            let monthLabel = formatter.string(from: period.start)
            
            data.insert(TrendData(month: monthLabel, income: income, expense: expense), at: 0)
            
            currentDate = FinancialMonthHelper.shiftFinancialAnchor(currentDate, by: -1, startDay: startDay)
        }
        
        return data
    }
    
    // MARK: - Suggestions
    private var suggestionsSection: some View {
        let suggestions = InsightsGenerator.generateSuggestions(
            transactions: transactions,
            categories: categories,
            monthKey: selectedMonthKey,
            periodStart: currentPeriod.start,
            periodEndExclusive: currentPeriod.endExclusive,
            primaryCode: primaryCode
        )
        
        return SuggestionsCard(suggestions: suggestions)
    }
    
    // MARK: - Summary
    private var monthSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Month Summary")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                monthSummaryCard(currency: .primary, code: primaryCode, color: .blue)
                monthSummaryCard(currency: .secondary, code: secondaryCode, color: .green)
            }
        }
    }
    
    private func monthSummaryCard(currency: CurrencyType, code: String, color: Color) -> some View {
        // Opening balance should be everything strictly BEFORE current period start
        let opening = BalanceCalculator.openingBalance(transactions: transactions, currency: currency, before: currentPeriod.start)
        
        // Optimization: Use monthlyTransactions for these calculations
        // We can just sum them up directly or use BalanceCalculator helper on the filtered list
        let income = BalanceCalculator.calculateTotal(transactions: monthlyTransactions, type: .income, currency: currency)
        let expense = BalanceCalculator.calculateTotal(transactions: monthlyTransactions, type: .expense, currency: currency)
        
        // Closing = Opening + Net
        let closing = opening + (income - expense)
        
        return VStack(spacing: 12) {
            HStack {
                Text(code)
                    .font(.headline)
                    .foregroundColor(color)
                Spacer()
            }
            
            HStack {
                summaryItem(label: "Opening", amount: opening, code: code)
                Spacer()
                summaryItem(label: "Income", amount: income, code: code, color: .green)
            }
            
            HStack {
                summaryItem(label: "Expense", amount: expense, code: code, color: .red)
                Spacer()
                summaryItem(label: "Closing", amount: closing, code: code, isBold: true)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func summaryItem(label: String, amount: Decimal, code: String, color: Color? = nil, isBold: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(MoneyFormatter.format(amount, currencyCode: code))
                .font(isBold ? .subheadline.bold() : .subheadline)
                .foregroundColor(color ?? (amount >= 0 ? .primary : .red))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }
}

struct WidgetDropDelegate: DropDelegate {
    let item: String
    @Binding var items: [String]
    @Binding var draggedItem: String?
    let onSave: () -> Void
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem,
              draggedItem != item,
              let from = items.firstIndex(of: draggedItem),
              let to = items.firstIndex(of: item)
        else { return }
        
        if items[to] != draggedItem {
            withAnimation {
                items.move(fromOffsets: IndexSet(integer: from), toOffset: from < to ? to + 1 : to)
            }
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        self.draggedItem = nil
        onSave() // Save to Settings
        return true
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Transaction.self, Category.self, BudgetMonth.self, CategoryBudget.self, CategoryGroup.self, AppSettings.self], inMemory: true)
}
