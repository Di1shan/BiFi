import SwiftUI
import SwiftData

// MARK: - Transactions View
struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var categories: [Category]
    @Query private var settings: [AppSettings]
    
    @State private var selectedDate: Date = Date()
    @State private var typeFilter: TypeFilter = .all
    @State private var currencyFilter: CurrencyFilter = .all
    @State private var sortOption: SortOption = .date
    @State private var searchText: String = ""
    @State private var showAddTransaction = false
    @State private var transactionToEdit: Transaction?
    
    // Sort Options
    enum SortOption: String, CaseIterable, Identifiable {
        case date = "Date"
        case category = "Category"
        case group = "Group"
        case highest = "Highest Amount"
        case lowest = "Lowest Amount"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .date: return "calendar"
            case .category: return "tag"
            case .group: return "folder"
            case .highest: return "arrow.up.circle"
            case .lowest: return "arrow.down.circle"
            }
        }
    }
    
    // ... existing properties ...
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
    
    // Pre-computed dictionary for O(1) category lookups
    private var categoriesById: [UUID: Category] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }
    
    private var filteredTransactions: [Transaction] {
        let period = currentPeriod
        
        return allTransactions.filter { transaction in
            // Month filter
            guard transaction.date >= period.start && transaction.date < period.endExclusive else { return false }
            
            // Type filter
            if typeFilter != .all {
                let requiredType: TransactionType = typeFilter == .income ? .income : .expense
                guard transaction.type == requiredType else { return false }
            }
            
            // Currency filter
            if currencyFilter != .all {
                let requiredCurrency: CurrencyType = currencyFilter == .primary ? .primary : .secondary
                guard transaction.currency == requiredCurrency else { return false }
            }
            
            // Search filter
            if !searchText.isEmpty {
                let noteMatch = transaction.note.localizedCaseInsensitiveContains(searchText)
                let categoryMatch: Bool = {
                    guard let categoryId = transaction.categoryId,
                          let category = categories.first(where: { $0.id == categoryId }) else {
                        return false
                    }
                    return category.name.localizedCaseInsensitiveContains(searchText)
                }()
                guard noteMatch || categoryMatch else { return false }
            }
            
            return true
        }
    }
    
    private var groupedTransactions: [(header: String, transactions: [Transaction])] {
        let transactions = filteredTransactions
        
        switch sortOption {
        case .date:
            let calendar = Calendar.current
            let grouped = Dictionary(grouping: transactions) { transaction in
                calendar.startOfDay(for: transaction.date)
            }
            let sortedDates = grouped.keys.sorted(by: >)
            return sortedDates.map { date in
                (header: MonthHelper.dayHeader(from: date), transactions: grouped[date]!.sorted { $0.date > $1.date })
            }
            
        case .category:
            let grouped = Dictionary(grouping: transactions) { transaction -> String in
                if let catId = transaction.categoryId, let cat = categories.first(where: { $0.id == catId }) {
                    return cat.name
                }
                return "Uncategorized"
            }
            let sortedKeys = grouped.keys.sorted()
            return sortedKeys.map { key in
                (header: key, transactions: grouped[key]!.sorted { $0.date > $1.date })
            }
            
        case .group:
            let grouped = Dictionary(grouping: transactions) { transaction -> String in
                if let catId = transaction.categoryId, 
                   let cat = categories.first(where: { $0.id == catId }),
                   let group = cat.group {
                    return group.name.uppercased()
                }
                return "OTHER"
            }
            let sortedKeys = grouped.keys.sorted()
            return sortedKeys.map { key in
                (header: key, transactions: grouped[key]!.sorted { $0.date > $1.date })
            }
            
        case .highest:
            let sorted = transactions.sorted { $0.amount > $1.amount }
            if sorted.isEmpty { return [] }
            return [(header: "Highest to Lowest", transactions: sorted)]
            
        case .lowest:
            let sorted = transactions.sorted { $0.amount < $1.amount }
            if sorted.isEmpty { return [] }
            return [(header: "Lowest to Highest", transactions: sorted)]
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // Custom Header
                    HStack {
                        Text("Transactions")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    monthSelector
                        .padding()
                    
                    filterSection
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                    
                    searchBar
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    
                    if filteredTransactions.isEmpty {
                        emptyStateView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        transactionList
                    }
                }
                
                addButton
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddTransaction) {
                AddEditTransactionView()
            }
            .sheet(item: $transactionToEdit) { transaction in
                AddEditTransactionView(transaction: transaction)
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search notes or categories", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Menu {
                Picker("Sort By", selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Label(option.rawValue, systemImage: option.icon)
                            .tag(option)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(sortOption == .date ? .secondary : AppTheme.accentPurple)
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
        }
    }
    
    // MARK: - Month Selector (Same as before)
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
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedDate)
    }
    
    // MARK: - Filter Section (Same as before)
    private var filterSection: some View {
        HStack(spacing: 12) {
            Picker("Type", selection: $typeFilter) {
                ForEach(TypeFilter.allCases) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            
            Picker("Currency", selection: $currencyFilter) {
                Text("All").tag(CurrencyFilter.all)
                Text(primaryCode).tag(CurrencyFilter.primary)
                Text(secondaryCode).tag(CurrencyFilter.secondary)
            }
            .pickerStyle(.segmented)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: typeFilter)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currencyFilter)
    }
    
    // MARK: - Transaction List (Updated)
    private var transactionList: some View {
        List {
            ForEach(groupedTransactions, id: \.header) { group in
                Section {
                    ForEach(group.transactions, id: \.id) { transaction in
                        TransactionRowView(
                            transaction: transaction,
                            category: transaction.categoryId.flatMap { categoriesById[$0] },
                            currencyCode: transaction.currency == .primary ? primaryCode : secondaryCode
                        )
                        .springRow(index: getIndex(for: transaction))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteTransaction(transaction)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                transactionToEdit = transaction
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                } header: {
                    Text(group.header)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            // Bottom Padding for Tab Bar
            Section {
                Color.clear
                    .frame(height: 120)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filteredTransactions.count)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sortOption)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        EmptyStateView(
            icon: "doc.text.magnifyingglass",
            title: "No Transactions",
            subtitle: "Add your first transaction to start tracking your finances",
            actionTitle: "Add Transaction",
            action: { showAddTransaction = true }
        )
    }
    
    // MARK: - Add Button
    private var addButton: some View {
        FloatingActionButton(
            icon: "plus",
            gradient: AppTheme.primaryGradient
        ) {
            showAddTransaction = true
        }
        .padding()
        .padding(.bottom, 100) // Clear Tab Bar
    }
    
    private func deleteTransaction(_ transaction: Transaction) {
        HapticsHelper.shared.notification(.warning)
        modelContext.delete(transaction)
        try? modelContext.save()
    }
    
    private func getIndex(for transaction: Transaction) -> Int {
        return filteredTransactions.firstIndex(where: { $0.id == transaction.id }) ?? 0
    }
}

// ... TransactionRowView and Preview ...
struct TransactionRowView: View {
    let transaction: Transaction
    let category: Category?
    let currencyCode: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: category?.icon ?? "questionmark.circle")
                    .font(.title3)
                    .foregroundColor(categoryColor)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(category?.name ?? "Uncategorized")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    if let groupName = category?.group?.name {
                        Text(groupName.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryColor.opacity(0.15))
                            .foregroundColor(categoryColor)
                            .clipShape(Capsule())
                    }
                }
                
                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedAmount)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(transaction.type == .income ? .green : .red)
                
                Text(transaction.currency == .primary ? "Primary" : "Secondary")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
    
    private var categoryColor: Color {
        if let hex = category?.colorHex {
            return Color(hex: hex)
        }
        return AppTheme.accentPurple
    }
    
    private var formattedAmount: String {
        let sign = transaction.type == .income ? "+" : "-"
        return sign + MoneyFormatter.format(transaction.amount, currencyCode: currencyCode)
    }
}

#Preview {
    TransactionsView()
        .modelContainer(for: [Transaction.self, Category.self, BudgetMonth.self, AppSettings.self], inMemory: true)
}
