import SwiftUI
import SwiftData

// MARK: - Add/Edit Transaction View
struct AddEditTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var settings: [AppSettings]
    
    // Either editing existing or creating new
    private var existingTransaction: Transaction?
    private var prefillType: TransactionType?
    
    @State private var transactionType: TransactionType = .expense
    @State private var currency: CurrencyType = .primary
    @State private var amountText: String = ""
    @State private var date: Date = Date()
    @State private var selectedCategoryId: UUID?
    @State private var note: String = ""
    @State private var showValidationError = false
    
    private var currentSettings: AppSettings? {
        settings.first
    }
    
    private var primaryCode: String {
        currentSettings?.primaryCurrencyCode ?? "LKR"
    }
    
    private var secondaryCode: String {
        currentSettings?.secondaryCurrencyCode ?? "AUD"
    }
    
    private var isEditing: Bool {
        existingTransaction != nil
    }
    
    private var isValid: Bool {
        guard let amount = MoneyFormatter.parse(amountText), amount > 0 else {
            return false
        }
        // Category is required for expense and savings
        if (transactionType == .expense || transactionType == .savings) && selectedCategoryId == nil {
            return false
        }
        return true
    }
    
    // MARK: - Initializers
    init(transaction: Transaction? = nil, prefillType: TransactionType? = nil) {
        self.existingTransaction = transaction
        self.prefillType = prefillType
    }
    
    // MARK: - Lifecycle
    private func loadTransactionData() {
        if let transaction = existingTransaction {
            transactionType = transaction.type
            currency = transaction.currency
            amountText = "\(transaction.amount)"
            date = transaction.date
            selectedCategoryId = transaction.categoryId
            note = transaction.note
        } else if let prefill = prefillType {
            transactionType = prefill
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Type Selection
                Section {
                    Picker("Type", selection: $transactionType) {
                        ForEach(TransactionType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 8)
                }
                
                // Currency Selection
                Section {
                    Picker("Currency", selection: $currency) {
                        Text(primaryCode).tag(CurrencyType.primary)
                        Text(secondaryCode).tag(CurrencyType.secondary)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 8)
                }
                
                // Amount
                Section("Amount") {
                    HStack {
                        Text(currency == .primary ? primaryCode : secondaryCode)
                            .foregroundStyle(.secondary)
                        
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                }
                
                // Date
                Section("Date") {
                    DatePicker("Transaction Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
                
                // Category
                Section("Category") {
                    categoryPicker
                }
                
                // Note
                Section("Note") {
                    TextField("Add a note (optional)", text: $note, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle(isEditing ? "Edit Transaction" : "Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTransaction()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .onAppear {
                loadTransactionData()
                setDefaultCategory()
            }
            .onChange(of: transactionType) { _, _ in
                setDefaultCategory()
            }
            .alert("Invalid Amount", isPresented: $showValidationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please enter an amount greater than zero.")
            }
        }
    }
    
    private var filteredCategories: [Category] {
        categories.filter { category in
            switch transactionType {
            case .expense:
                return category.isExpenseEnabled
            case .income:
                return category.isIncomeEnabled
            case .savings:
                return category.isSavingsEnabled
            }
        }
    }
    
    // MARK: - Category Picker
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(filteredCategories) { category in
                    categoryButton(for: category)
                }
            }
            .padding(.vertical, 8)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
    
    private func categoryButton(for category: Category) -> some View {
        let isSelected = selectedCategoryId == category.id
        
        return Button {
            HapticsHelper.shared.selection()
            selectedCategoryId = category.id
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(hex: category.colorHex).opacity(isSelected ? 1 : 0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: category.icon)
                        .font(.title3)
                        .foregroundColor(isSelected ? .white : Color(hex: category.colorHex))
                }
                
                Text(category.name)
                    .font(.caption)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    private func setDefaultCategory() {
        if selectedCategoryId == nil && transactionType == .income {
            selectedCategoryId = Category.salaryCategory(from: categories)?.id
        }
    }
    
    private func saveTransaction() {
        guard let amount = MoneyFormatter.parse(amountText), amount > 0 else {
            showValidationError = true
            return
        }
        
        HapticsHelper.shared.notification(.success)
        
        if let existing = existingTransaction {
            // Update existing
            existing.type = transactionType
            existing.currency = currency
            existing.amount = amount
            existing.date = date
            existing.categoryId = selectedCategoryId
            existing.note = note
            existing.updatedAt = Date()
        } else {
            // Create new
            let transaction = Transaction(
                date: date,
                note: note,
                categoryId: selectedCategoryId,
                type: transactionType,
                currency: currency,
                amount: amount
            )
            modelContext.insert(transaction)
        }
        
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddEditTransactionView()
        .modelContainer(for: [Transaction.self, Category.self, BudgetMonth.self, AppSettings.self], inMemory: true)
}
