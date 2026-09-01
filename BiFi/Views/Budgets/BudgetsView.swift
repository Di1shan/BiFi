import SwiftUI
import SwiftData

// MARK: - Budgets View
struct BudgetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var transactions: [Transaction]
    @Query(sort: \CategoryGroup.sortOrder) private var groups: [CategoryGroup]
    @Query private var settings: [AppSettings]
    
    @State private var selectedDate: Date = Date()
    @State private var categoryBudgets: [CategoryBudget] = []
    @State private var currentBudgetMonth: BudgetMonth?
    @State private var showConfetti = false
    @State private var selectedCategoryForBudget: Category?
    @State private var showCategoryManager = false
    @State private var showMonthBudgetSheet = false
    
    // Memoized calculations
    @State private var spendingByCategory: [UUID: (primary: Decimal, secondary: Decimal)] = [:]
    
    private var currentSettings: AppSettings? { settings.first }
    private var primaryCode: String { currentSettings?.primaryCurrencyCode ?? "LKR" }
    private var secondaryCode: String { currentSettings?.secondaryCurrencyCode ?? "AUD" }
    private var currentPeriod: (start: Date, endExclusive: Date, displayEnd: Date, key: String, title: String, rangeDescription: String) {
        FinancialMonthHelper.financialPeriod(
            containing: selectedDate,
            startDay: currentSettings?.effectiveFinancialStartDay ?? 1
        )
    }
    
    private var selectedMonthKey: String { currentPeriod.key }
    
    // Total from BudgetMonth (User Set)
    private var totalBudgetPrimary: Decimal {
        currentBudgetMonth?.primaryMonthlyBudget ?? 0
    }
    
    private var totalBudgetSecondary: Decimal {
        currentBudgetMonth?.secondaryMonthlyBudget ?? 0
    }
    
    // Sum of Categories (Allocated) - only count budgets with valid categories
    private var validCategoryBudgets: [CategoryBudget] {
        let categoryIds = Set(categories.map { $0.id })
        return categoryBudgets.filter { categoryIds.contains($0.categoryId) }
    }
    
    private var allocatedPrimary: Decimal {
        validCategoryBudgets.reduce(0) { $0 + $1.primaryLimit }
    }
    
    private var allocatedSecondary: Decimal {
        validCategoryBudgets.reduce(0) { $0 + $1.secondaryLimit }
    }
    
    private var totalSpentPrimary: Decimal {
        BalanceCalculator.periodExpense(transactions: transactions, currency: .primary, start: currentPeriod.start, endExclusive: currentPeriod.endExclusive)
    }
    
    private var totalSpentSecondary: Decimal {
        BalanceCalculator.periodExpense(transactions: transactions, currency: .secondary, start: currentPeriod.start, endExclusive: currentPeriod.endExclusive)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Custom Header
                    HStack {
                        Text("Budgets")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    monthSelector
                        .padding(.horizontal)
                    
                    // Summary Cards
                    VStack(spacing: 16) {
                        Button {
                            showMonthBudgetSheet = true
                        } label: {
                            summaryCard(
                                title: "Total Primary",
                                code: primaryCode,
                                spent: totalSpentPrimary,
                                budget: totalBudgetPrimary,
                                allocated: allocatedPrimary,
                                gradient: AppTheme.primaryGradient
                            )
                        }
                        .buttonStyle(BounceButtonStyle())
                        
                        Button {
                            showMonthBudgetSheet = true
                        } label: {
                            summaryCard(
                                title: "Total Secondary",
                                code: secondaryCode,
                                spent: totalSpentSecondary,
                                budget: totalBudgetSecondary,
                                allocated: allocatedSecondary,
                                gradient: AppTheme.expenseGradient
                            )
                        }
                        .buttonStyle(BounceButtonStyle())
                    }
                    .padding(.horizontal)
                    
                    // Categories Section
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            Text("Category Budgets")
                                .font(.headline)
                            Spacer()
                            
                            // Add Budget Button
                            Button {
                                showAddBudgetSheet = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(AppTheme.primaryGradient)
                            }
                            .buttonStyle(BounceButtonStyle())
                        }
                        .padding(.horizontal)
                        
                        LazyVStack(spacing: 24) {
                            ForEach(groups) { group in
                                let groupCategories = categories.filter { category in
                                    category.group?.id == group.id &&
                                    hasBudget(for: category)
                                }
                                
                                if !groupCategories.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text(group.name.uppercased())
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.secondary)
                                            .padding(.leading, 4)
                                        
                                        ForEach(groupCategories) { category in
                                            CategoryBudgetRow(
                                                category: category,
                                                budget: getBudget(for: category),
                                                spending: spendingByCategory[category.id] ?? (0, 0),
                                                primaryCode: primaryCode,
                                                secondaryCode: secondaryCode,
                                                onTap: { selectedCategoryForBudget = category }
                                            )
                                        }
                                    }
                                }
                            }
                            
                            // Uncategorized / No Group
                            let unassigned = categories.filter { category in
                                category.group == nil &&
                                hasBudget(for: category)
                            }
                            
                            if !unassigned.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("OTHER")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 4)
                                    
                                    ForEach(unassigned) { category in
                                        CategoryBudgetRow(
                                            category: category,
                                            budget: getBudget(for: category),
                                            spending: spendingByCategory[category.id] ?? (0, 0),
                                            primaryCode: primaryCode,
                                            secondaryCode: secondaryCode,
                                            onTap: { selectedCategoryForBudget = category }
                                        )
                                    }
                                }
                            }
                            
                            if categoryBudgets.isEmpty {
                                if previousMonthHasBudgets {
                                    VStack(spacing: 20) {
                                        Image(systemName: "doc.on.doc.fill")
                                            .font(.system(size: 40))
                                            .foregroundStyle(AppTheme.primaryGradient)
                                            .padding(.bottom, 4)
                                        
                                        Text("New Month, Same Goals?")
                                            .font(.headline)
                                        
                                        Text("You can copy your budgets from last month or start fresh.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                        
                                        Button {
                                            copyFromPreviousMonth()
                                        } label: {
                                            Text("Copy Last Month's Budgets")
                                                .fontWeight(.semibold)
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(AppTheme.primaryGradient)
                                                .foregroundColor(.white)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                        .buttonStyle(BounceButtonStyle())
                                        
                                        Button {
                                            showAddBudgetSheet = true
                                        } label: {
                                            Text("Start Fresh")
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                    .padding(24)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .padding(.top, 10)
                                } else {
                                    EmptyStateView(
                                        icon: "chart.bar.doc.horizontal",
                                        title: "No Budgets Set",
                                        subtitle: "Tap the + button to start budgeting for your categories.",
                                        actionTitle: "Add Budget"
                                    ) {
                                        showAddBudgetSheet = true
                                    }
                                    .padding(.top, 20)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Bottom Padding for Tab Bar
                    Color.clear.frame(height: 80)
                    
                    if showConfetti {
                        ConfettiView().allowsHitTesting(false)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Budgets")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .sheet(isPresented: $showCategoryManager) {
                CategoryManagerView()
            }
            .sheet(isPresented: $showMonthBudgetSheet) {
                SetMonthlyBudgetSheet(
                    monthKey: selectedMonthKey,
                    currentBudget: currentBudgetMonth,
                    primaryCode: primaryCode,
                    secondaryCode: secondaryCode,
                    monthTitle: currentPeriod.title
                ) { primary, secondary in
                    saveMonthlyBudget(primary: primary, secondary: secondary)
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showAddBudgetSheet) {
                AddBudgetSheet(
                    categories: categories,
                    currentBudgets: categoryBudgets,
                    primaryCode: primaryCode,
                    secondaryCode: secondaryCode
                ) { category, primary, secondary in
                    saveBudget(for: category, primary: primary, secondary: secondary)
                }
                .presentationDetents([.fraction(0.4), .medium])
            }
            .sheet(item: $selectedCategoryForBudget) { category in
                SetCategoryBudgetSheet(
                    category: category,
                    currentBudget: getBudget(for: category),
                    monthKey: selectedMonthKey,
                    monthTitle: currentPeriod.title,
                    primaryCode: primaryCode,
                    secondaryCode: secondaryCode,
                    onSave: { primary, secondary in
                        saveBudget(for: category, primary: primary, secondary: secondary)
                    },
                    onRemove: {
                        removeBudget(for: category)
                    }
                )
                .presentationDetents([.medium])
            }
        }
        .onAppear {
            refreshData()
        }
        .onChange(of: selectedMonthKey) { _, _ in
            refreshData()
        }
        .onChange(of: transactions) { _, _ in
            calculateSpending()
        }
    }
    
    // MARK: - Helpers
    @State private var previousMonthHasBudgets = false
    
    private func getBudget(for category: Category) -> CategoryBudget? {
        categoryBudgets.first { $0.categoryId == category.id }
    }
    
    private func hasBudget(for category: Category) -> Bool {
        if let budget = getBudget(for: category) {
            return budget.primaryLimit > 0 || budget.secondaryLimit > 0
        }
        return false
    }
    
    private func refreshData() {
        // Fetch Budgets
        let descriptor = FetchDescriptor<CategoryBudget>(
            predicate: #Predicate { $0.monthKey == selectedMonthKey }
        )
        categoryBudgets = (try? modelContext.fetch(descriptor)) ?? []
        
        // Fetch Monthly Budget
        let monthDescriptor = FetchDescriptor<BudgetMonth>(
            predicate: #Predicate { $0.monthKey == selectedMonthKey }
        )
        currentBudgetMonth = try? modelContext.fetch(monthDescriptor).first
        
        // Check Previous Month
        let prevDate = FinancialMonthHelper.shiftFinancialAnchor(
            selectedDate,
            by: -1,
            startDay: currentSettings?.effectiveFinancialStartDay ?? 1
        )
        let prevKey = FinancialMonthHelper.financialPeriod(
            containing: prevDate,
            startDay: currentSettings?.effectiveFinancialStartDay ?? 1
        ).key
        let prevDescriptor = FetchDescriptor<CategoryBudget>(
            predicate: #Predicate { $0.monthKey == prevKey }
        )
        let prevCount = (try? modelContext.fetchCount(prevDescriptor)) ?? 0
        previousMonthHasBudgets = prevCount > 0
        
        calculateSpending()
    }
    
    private func copyFromPreviousMonth() {
        let prevDate = FinancialMonthHelper.shiftFinancialAnchor(
            selectedDate,
            by: -1,
            startDay: currentSettings?.effectiveFinancialStartDay ?? 1
        )
        let prevKey = FinancialMonthHelper.financialPeriod(
            containing: prevDate,
            startDay: currentSettings?.effectiveFinancialStartDay ?? 1
        ).key
        
        // Fetch previous budgets
        let descriptor = FetchDescriptor<CategoryBudget>(
            predicate: #Predicate { $0.monthKey == prevKey }
        )
        
        guard let prevBudgets = try? modelContext.fetch(descriptor) else { return }
        
        for budget in prevBudgets {
            let newBudget = CategoryBudget(
                categoryId: budget.categoryId,
                monthKey: selectedMonthKey,
                primaryLimit: budget.primaryLimit,
                secondaryLimit: budget.secondaryLimit
            )
            modelContext.insert(newBudget)
        }
        
        // Also try to copy the total monthly budget
        let monthDescriptor = FetchDescriptor<BudgetMonth>(
            predicate: #Predicate { $0.monthKey == prevKey }
        )
        if let prevMonthBudget = try? modelContext.fetch(monthDescriptor).first {
            let newMonthBudget = BudgetMonth(
                monthKey: selectedMonthKey,
                primaryMonthlyBudget: prevMonthBudget.primaryMonthlyBudget,
                secondaryMonthlyBudget: prevMonthBudget.secondaryMonthlyBudget
            )
            modelContext.insert(newMonthBudget)
        }
        
        try? modelContext.save()
        refreshData()
        HapticsHelper.shared.notification(.success)
        showConfetti = true
    }
    
    private func calculateSpending() {
        var spending: [UUID: (Decimal, Decimal)] = [:]
        
        // Filter transactions for this month
        let period = currentPeriod
        
        let monthTransactions = transactions.filter {
            $0.date >= period.start && $0.date < period.endExclusive && $0.type == .expense
        }
        
        for category in categories {
            // Primary
            let primary = monthTransactions
                .filter { $0.categoryId == category.id && $0.currency == .primary }
                .reduce(0) { $0 + $1.amount }
            
            // Secondary
            let secondary = monthTransactions
                .filter { $0.categoryId == category.id && $0.currency == .secondary }
                .reduce(0) { $0 + $1.amount }
                
            spending[category.id] = (primary, secondary)
        }
        spendingByCategory = spending
    }
    
    private func saveBudget(for category: Category, primary: Decimal, secondary: Decimal) {
        if let existing = getBudget(for: category) {
            existing.primaryLimit = primary
            existing.secondaryLimit = secondary
            existing.updatedAt = Date()
        } else {
            let newBudget = CategoryBudget(
                categoryId: category.id,
                monthKey: selectedMonthKey,
                primaryLimit: primary,
                secondaryLimit: secondary
            )
            modelContext.insert(newBudget)
        }
        
        try? modelContext.save()
        refreshData()
        HapticsHelper.shared.notification(.success)
    }
    
    private func removeBudget(for category: Category) {
        if let existing = getBudget(for: category) {
            modelContext.delete(existing)
            try? modelContext.save()
            refreshData()
            HapticsHelper.shared.notification(.success)
        }
    }
    
    private func saveMonthlyBudget(primary: Decimal, secondary: Decimal) {
        if let existing = currentBudgetMonth {
            existing.primaryMonthlyBudget = primary
            existing.secondaryMonthlyBudget = secondary
            existing.updatedAt = Date()
        } else {
            let newMonth = BudgetMonth(
                monthKey: selectedMonthKey,
                primaryMonthlyBudget: primary,
                secondaryMonthlyBudget: secondary
            )
            modelContext.insert(newMonth)
        }
        try? modelContext.save()
        refreshData()
        HapticsHelper.shared.notification(.success)
    }

    @State private var showAddBudgetSheet = false
    
    // MARK: - Month Selector (Reused)
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
    
    // MARK: - Summary Card
    private func summaryCard(title: String, code: String, spent: Decimal, budget: Decimal, allocated: Decimal, gradient: LinearGradient) -> some View {

        let isExceeded = budget > 0 && spent > budget
        
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(MoneyFormatter.format(spent, currencyCode: code))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isExceeded ? .red : .primary)
            }
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(budget > 0 ? "Total Limit" : "No Limit Set")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if budget > 0 {
                    Text(MoneyFormatter.format(budget, currencyCode: code))
                        .font(.headline)
                } else {
                    Text("Tap to Set")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                
                if allocated > 0 {
                    Text("Allocated: \(MoneyFormatter.format(allocated, currencyCode: ""))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(gradient, lineWidth: 1)
                .opacity(0.3)
        )
    }
}

// MARK: - Category Budget Row
struct CategoryBudgetRow: View {
    let category: Category
    let budget: CategoryBudget?
    let spending: (primary: Decimal, secondary: Decimal)
    let primaryCode: String
    let secondaryCode: String
    let onTap: () -> Void
    
    private var hasBudget: Bool {
        (budget?.primaryLimit ?? 0) > 0 || (budget?.secondaryLimit ?? 0) > 0
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Header
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color(hex: category.colorHex).opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: category.icon)
                            .foregroundColor(Color(hex: category.colorHex))
                    }
                    
                    Text(category.name)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if !hasBudget {
                        Text("Set Limit")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if hasBudget {
                    HStack(alignment: .top, spacing: 16) {
                        budgetColumn(
                            code: primaryCode,
                            spent: spending.primary,
                            limit: budget?.primaryLimit ?? 0
                        )
                        
                        Divider().frame(height: 30)
                        
                        budgetColumn(
                            code: secondaryCode,
                            spent: spending.secondary,
                            limit: budget?.secondaryLimit ?? 0
                        )
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(BounceButtonStyle())
    }
    
    private func budgetColumn(code: String, spent: Decimal, limit: Decimal) -> some View {
        let progress = limit > 0 ? (spent / limit) : 0
        let isExceeded = limit > 0 && spent > limit
        let color: Color = isExceeded ? .red : (progress > 0.8 ? .orange : Color(hex: category.colorHex))
        
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(code)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(min(progress.doubleValue * 100, 999)))%")
                    .font(.caption2)
                    .foregroundColor(color)
            }
            
            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray6))
                    Capsule()
                        .fill(color)
                        .frame(width: min(geo.size.width * CGFloat(progress.doubleValue), geo.size.width))
                }
            }
            .frame(height: 6)
            
            HStack {
                Text(MoneyFormatter.format(spent, currencyCode: ""))
                    .font(.caption2)
                    .foregroundColor(isExceeded ? .red : .primary)
                Text("/")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(MoneyFormatter.format(limit, currencyCode: ""))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Set Monthly Budget Sheet
struct SetMonthlyBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let monthKey: String
    let currentBudget: BudgetMonth?
    let primaryCode: String
    let secondaryCode: String
    let monthTitle: String
    let onSave: (Decimal, Decimal) -> Void
    
    @State private var primaryAmount: String = ""
    @State private var secondaryAmount: String = ""
    
    init(monthKey: String, currentBudget: BudgetMonth?, primaryCode: String, secondaryCode: String, monthTitle: String, onSave: @escaping (Decimal, Decimal) -> Void) {
        self.monthKey = monthKey
        self.currentBudget = currentBudget
        self.primaryCode = primaryCode
        self.secondaryCode = secondaryCode
        self.monthTitle = monthTitle
        self.onSave = onSave
        
        _primaryAmount = State(initialValue: currentBudget?.primaryMonthlyBudget.description ?? "")
        _secondaryAmount = State(initialValue: currentBudget?.secondaryMonthlyBudget.description ?? "")
        
        if let p = currentBudget?.primaryMonthlyBudget, p == 0 { _primaryAmount = State(initialValue: "") }
        if let s = currentBudget?.secondaryMonthlyBudget, s == 0 { _secondaryAmount = State(initialValue: "") }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(primaryCode)
                        TextField("0.00", text: $primaryAmount)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text(secondaryCode)
                        TextField("0.00", text: $secondaryAmount)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Total Monthly Limits")
                } footer: {
                    Text("Set the total budget for \(monthTitle). This overrides the sum of category budgets for the top summary.")
                }
            }
            .navigationTitle("Monthly Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let p = MoneyFormatter.parse(primaryAmount) ?? 0
                        let s = MoneyFormatter.parse(secondaryAmount) ?? 0
                        onSave(p, s)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Add Budget Sheet
struct AddBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let categories: [Category]
    let currentBudgets: [CategoryBudget]
    let primaryCode: String
    let secondaryCode: String
    let onSave: (Category, Decimal, Decimal) -> Void
    
    @State private var selectedCategory: Category?
    @State private var primaryAmount = ""
    @State private var secondaryAmount = ""
    
    private var availableCategories: [Category] {
        categories.filter { category in
            !currentBudgets.contains(where: { $0.categoryId == category.id && ($0.primaryLimit > 0 || $0.secondaryLimit > 0) })
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if availableCategories.isEmpty {
                    Section {
                        Text("All categories already have budgets allocated for this month.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Select Category") {
                        Picker("Category", selection: $selectedCategory) {
                            Text("Select a category...").tag(nil as Category?)
                            ForEach(availableCategories) { category in
                                Label(category.name, systemImage: category.icon)
                                    .tag(category as Category?)
                            }
                        }
                    }
                    
                    if selectedCategory != nil {
                        Section("Budget Limits") {
                            HStack {
                                Text(primaryCode)
                                TextField("0.00", text: $primaryAmount)
                                    .keyboardType(.decimalPad)
                            }
                            
                            HStack {
                                Text(secondaryCode)
                                TextField("0.00", text: $secondaryAmount)
                                    .keyboardType(.decimalPad)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let category = selectedCategory {
                            let p = MoneyFormatter.parse(primaryAmount) ?? 0
                            let s = MoneyFormatter.parse(secondaryAmount) ?? 0
                            onSave(category, p, s)
                        }
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(selectedCategory == nil)
                }
            }
        }
    }
}

// MARK: - Set Budget Sheet (Category)
struct SetCategoryBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let category: Category
    let currentBudget: CategoryBudget?
    let monthKey: String
    let monthTitle: String // New param
    let primaryCode: String
    let secondaryCode: String
    let onSave: (Decimal, Decimal) -> Void
    let onRemove: () -> Void
    
    @State private var primaryAmount: String = ""
    @State private var secondaryAmount: String = ""
    @State private var showRemoveAlert = false
    
    init(category: Category, currentBudget: CategoryBudget?, monthKey: String, monthTitle: String, primaryCode: String, secondaryCode: String, onSave: @escaping (Decimal, Decimal) -> Void, onRemove: @escaping () -> Void) {
        self.category = category
        self.currentBudget = currentBudget
        self.monthKey = monthKey
        self.monthTitle = monthTitle
        self.primaryCode = primaryCode
        self.secondaryCode = secondaryCode
        self.onSave = onSave
        self.onRemove = onRemove
        
        _primaryAmount = State(initialValue: currentBudget?.primaryLimit.description ?? "")
        _secondaryAmount = State(initialValue: currentBudget?.secondaryLimit.description ?? "")
        
        // Clean up "0"
        if let p = currentBudget?.primaryLimit, p == 0 { _primaryAmount = State(initialValue: "") }
        if let s = currentBudget?.secondaryLimit, s == 0 { _secondaryAmount = State(initialValue: "") }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(primaryCode)
                        TextField("0.00", text: $primaryAmount)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text(secondaryCode)
                        TextField("0.00", text: $secondaryAmount)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Budget Limits for \(category.name)")
                } footer: {
                    Text("Set spending limits for this category for \(monthTitle)")
                }
                
                Section {
                    Button(role: .destructive) {
                        showRemoveAlert = true
                    } label: {
                        Text("Remove from Budget")
                    }
                }
            }
            .navigationTitle("Set Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let p = MoneyFormatter.parse(primaryAmount) ?? 0
                        let s = MoneyFormatter.parse(secondaryAmount) ?? 0
                        onSave(p, s)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .alert("Remove Budget?", isPresented: $showRemoveAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    onRemove()
                    dismiss()
                }
            } message: {
                Text("This will remove \(category.name) from the budget list for this month. The category itself will remain available.")
            }
        }
    }
}

#Preview {
    BudgetsView()
        .modelContainer(for: [Transaction.self, Category.self, BudgetMonth.self, CategoryBudget.self, CategoryGroup.self, AppSettings.self], inMemory: true)
}
