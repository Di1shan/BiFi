import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsQuery: [AppSettings]
    @Environment(AuthenticationManager.self) private var authManager
    @State private var showCSVImport = false
    @State private var showCSVExport = false
    
    // Backup & Restore State
    @State private var showRestoreFilePicker = false
    @State private var activeAlert: ActiveAlert?
    
    // CSV State
    @State private var showCSVImporter = false // Not used? we use showCSVImport
    @State private var importError: String?
    @State private var showResetAlert = false
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    
    // SwiftData Queries for Export
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Category.name) private var categories: [Category]
    
    // Alert Enum
    enum ActiveAlert: Identifiable {
        case error(String)
        case restoreConfirmation
        case success(String)
        
        var id: String {
            switch self {
            case .error: return "error"
            case .restoreConfirmation: return "restore"
            case .success: return "success"
            }
        }
    }
    
    private var currentSettings: AppSettings? {
        settingsQuery.first
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Custom Header
                Section {
                    HStack {
                        Text("Settings")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .listRowBackground(Color(.systemGroupedBackground))
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
                }
                .listSectionSeparator(.hidden)
                
                // Financial Month
                // Financial Month
                Section("Financial Month") {
                    Toggle("Use Custom Financial Month", isOn: Binding(
                        get: { currentSettings?.financialMonthEnabled ?? false },
                        set: { newValue in
                            currentSettings?.financialMonthEnabled = newValue
                            currentSettings?.updatedAt = Date()
                            try? modelContext.save()
                        }
                    ))
                    
                    if currentSettings?.financialMonthEnabled == true {
                        Picker("Start Day", selection: Binding(
                            get: { currentSettings?.financialMonthStartDay ?? 1 },
                            set: { newValue in
                                currentSettings?.financialMonthStartDay = newValue
                                currentSettings?.updatedAt = Date()
                                try? modelContext.save()
                            }
                        )) {
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                        
                        Text("If the selected day doesn't exist in a month, it will use the last day of that month.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("Current financial period: " + (currentSettings.map {
                        FinancialMonthHelper.financialPeriod(
                            containing: Date(),
                            startDay: $0.effectiveFinancialStartDay
                        ).rangeDescription
                    } ?? ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                // Currency Settings
                Section("Currency") {
                    NavigationLink {
                        CurrencyPickerView(
                            title: "Primary Currency",
                            selectedCode: Binding(
                                get: { currentSettings?.primaryCurrencyCode ?? "LKR" },
                                set: { newValue in
                                    currentSettings?.primaryCurrencyCode = newValue
                                    currentSettings?.updatedAt = Date()
                                    try? modelContext.save()
                                }
                            )
                        )
                    } label: {
                        HStack {
                            Image(systemName: "banknote.fill")
                                .foregroundColor(AppTheme.accentCyan)
                            Text("Primary Currency")
                            Spacer()
                            Text(currentSettings?.primaryCurrencyCode ?? "LKR")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    NavigationLink {
                        CurrencyPickerView(
                            title: "Secondary Currency",
                            selectedCode: Binding(
                                get: { currentSettings?.secondaryCurrencyCode ?? "AUD" },
                                set: { newValue in
                                    currentSettings?.secondaryCurrencyCode = newValue
                                    currentSettings?.updatedAt = Date()
                                    try? modelContext.save()
                                }
                            )
                        )
                    } label: {
                        HStack {
                            Image(systemName: "banknote")
                                .foregroundColor(AppTheme.accentGreen)
                            Text("Secondary Currency")
                            Spacer()
                            Text(currentSettings?.secondaryCurrencyCode ?? "AUD")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Appearance
                Section("Appearance") {
                    Picker("Theme", selection: Binding(
                        get: { currentSettings?.appearance ?? .system },
                        set: { newValue in
                            currentSettings?.appearance = newValue
                            currentSettings?.updatedAt = Date()
                            try? modelContext.save()
                        }
                    )) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }
                
                // Haptics
                Section("Feedback") {
                    Toggle("Haptic Feedback", isOn: Binding(
                        get: { currentSettings?.hapticsEnabled ?? true },
                        set: { newValue in
                            currentSettings?.hapticsEnabled = newValue
                            currentSettings?.updatedAt = Date()
                            try? modelContext.save()
                            HapticsHelper.shared.updateEnabled(newValue)
                        }
                    ))
                }
                
                // Security
                Section {
                    Toggle("App Lock", isOn: Binding(
                        get: { currentSettings?.appLockEnabled ?? false },
                        set: { newValue in
                            if newValue && !authManager.canUseBiometrics {
                                // Cannot enable without biometrics
                                return
                            }
                            currentSettings?.appLockEnabled = newValue
                            currentSettings?.updatedAt = Date()
                            try? modelContext.save()
                            if newValue {
                                authManager.isUnlocked = true
                            }
                        }
                    ))
                    
                    if !authManager.canUseBiometrics {
                        Text("Biometric authentication is not available on this device")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        (Text("Use ") + Text(authManager.biometricType.displayName) + Text(" to unlock the app"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Security")
                } footer: {
                    if currentSettings?.appLockEnabled == true {
                        (Text("The app will lock when you leave and require ") + Text(authManager.biometricType.displayName) + Text(" to unlock"))
                    }
                }
                
                // Categories
                Section("Categories") {
                    NavigationLink {
                        CategoryManagerView()
                    } label: {
                        Label {
                            Text("Manage Categories")
                        } icon: {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(AppTheme.primaryGradient)
                        }
                    }
                }
                
                // Data Management
                Section("Data Management") {
                    Button {
                        performBackup()
                    } label: {
                        Label {
                            Text("Backup Data")
                            Text("Save a copy of your data locally")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } icon: {
                            Image(systemName: "square.and.arrow.up.on.square")
                                .foregroundStyle(.blue)
                        }
                    }
                    .sheet(item: $backupFile) { file in
                        ShareSheet(items: [file.url])
                    }
                    
                    Button {
                        activeAlert = .restoreConfirmation
                    } label: {
                        Label {
                            Text("Restore Data")
                            Text("Import data from a backup file")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } icon: {
                            Image(systemName: "arrow.up.doc.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    // CSV Export
                    NavigationLink {
                        CSVExportView()
                    } label: {
                        Label("Export CSV", systemImage: "tablecells.badge.ellipsis")
                    }
                    
                    // CSV Import
                    NavigationLink {
                        CSVImportView()
                    } label: {
                        Label("Import CSV", systemImage: "square.and.arrow.down.on.square.fill")
                    }
                }
                
                Section("Danger Zone") {
                    Button("Reset All Data", role: .destructive) {
                        showResetAlert = true
                    }
                }
                
                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Bottom Padding for Tab Bar
                Section {
                    Color.clear
                        .frame(height: 60)
                        .listRowBackground(Color.clear)
                }
                .listSectionSeparator(.hidden)
            }
            .listSectionSpacing(0)
            .contentMargins(.top, 0)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .sheet(isPresented: $showCSVImport) {
                CSVImportSheet(isPresented: $showCSVImport)
            }
            .fileImporter(
                isPresented: $showRestoreFilePicker,
                allowedContentTypes: [.json, BackupManager.backupUTType],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert(item: $activeAlert) { type in
                switch type {
                case .error(let message):
                    return Alert(title: Text("Error"), message: Text(message), dismissButton: .default(Text("OK")))
                case .success(let message):
                    return Alert(title: Text("Success"), message: Text(message), dismissButton: .default(Text("OK")))
                case .restoreConfirmation:
                    return Alert(
                        title: Text("Restore Backup?"),
                        message: Text("Restoring will REPLACE all current data with the backup. This action cannot be undone."),
                        primaryButton: .destructive(Text("Select File")) {
                            showRestoreFilePicker = true
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
            .confirmationDialog("Reset All Data?", isPresented: $showResetAlert, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) {
                    resetAllData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all transactions, budgets, and custom categories. This cannot be undone.")
            }
    }
    }

    
    // MARK: - Actions
    // MARK: - Actions
    struct BackupFile: Identifiable {
        let id = UUID()
        let url: URL
    }
    
    @State private var backupFile: BackupFile?
    
    private func performBackup() {
        do {
            let url = try BackupManager.shared.createBackup(modelContext: modelContext)
            // Use item-based presentation to ensure URL is ready
            backupFile = BackupFile(url: url)
            print("Backup created at: \(url)")
        } catch {
            print("Backup failed: \(error)")
            activeAlert = .error("Failed to create backup: \(error.localizedDescription)")
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            
            try BackupManager.shared.restoreBackup(from: url, modelContext: modelContext)
            activeAlert = .success("Data restored successfully!")
        } catch {
            activeAlert = .error("Failed to restore backup: \(error.localizedDescription)")
        }
    }
    
    // MARK: - CSV Helpers
    private func generateCSVFile() -> URL {
        let csvString = CSVManager.generateCSV(from: transactions, categories: categories)
        let fileName = "DualBudget_Transactions_\(Date().formatted(date: .numeric, time: .omitted)).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try? csvString.write(to: tempURL, atomically: true, encoding: String.Encoding.utf8)
        return tempURL
    }
    
    private func exportCSV() {
        let url = generateCSVFile()
        exportURL = url
        showExportSheet = true
    }
    
    private func resetAllData() {
        // Delete all transactions
        for transaction in transactions {
            modelContext.delete(transaction)
        }
        
        // Delete all categories (except default ones will be recreated on next launch)
        for category in categories {
            modelContext.delete(category)
        }
        
        // Delete all budgets
        let fetchDescriptor = FetchDescriptor<BudgetMonth>()
        if let budgets = try? modelContext.fetch(fetchDescriptor) {
            for budget in budgets {
                modelContext.delete(budget)
            }
        }
        
        // Delete category budgets
        let categoryBudgetDescriptor = FetchDescriptor<CategoryBudget>()
        if let categoryBudgets = try? modelContext.fetch(categoryBudgetDescriptor) {
            for budget in categoryBudgets {
                modelContext.delete(budget)
            }
        }
        
        try? modelContext.save()
        activeAlert = .success("All data has been reset.")
    }
}



// MARK: - Currency Picker View
struct CurrencyPickerView: View {
    let title: String
    @Binding var selectedCode: String
    @State private var customCode: String = ""
    @State private var showCustomInput = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section("Common Currencies") {
                ForEach(AppSettings.commonCurrencyCodes, id: \.self) { code in
                    Button {
                        HapticsHelper.shared.selection()
                        selectedCode = code
                        dismiss()
                    } label: {
                        HStack {
                            Text(code)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedCode == code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            
            Section("Custom") {
                HStack {
                    TextField("Enter code (e.g., EUR)", text: $customCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    
                    Button("Set") {
                        let trimmed = customCode.trimmingCharacters(in: .whitespaces).uppercased()
                        if !trimmed.isEmpty {
                            HapticsHelper.shared.selection()
                            selectedCode = trimmed
                            dismiss()
                        }
                    }
                    .disabled(customCode.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .environment(AuthenticationManager())
        .modelContainer(for: [Transaction.self, Category.self, BudgetMonth.self, AppSettings.self], inMemory: true)
}


// MARK: - CSV Manager
struct CSVManager {
    static let header = "Date,Note,Amount,Currency,Type,Category,Group"
    
    // MARK: - Export
    static func generateCSV(from transactions: [Transaction], categories: [Category]) -> String {
        var csvString = header + "\n"
        
        for transaction in transactions.sorted(by: { $0.date > $1.date }) {
            let categoryName = categories.first(where: { $0.id == transaction.categoryId })?.name ?? "Uncategorized"
            let groupName = categories.first(where: { $0.id == transaction.categoryId })?.group?.name ?? ""
            
            let amount = String(format: "%.2f", NSDecimalNumber(decimal: transaction.amount).doubleValue)
            let date = transaction.date.formatted(date: .numeric, time: .omitted)
            let note = transaction.note.replacingOccurrences(of: ",", with: " ") // Simple sanitization
            let currency = transaction.currency == .primary ? "Primary" : "Secondary"
            let type = transaction.type == .income ? "Income" : "Expense"
            
            let line = "\(date),\(note),\(amount),\(currency),\(type),\(categoryName),\(groupName)"
            csvString.append(line + "\n")
        }
        
        return csvString
    }
    
    // MARK: - Import
    // Returns a list of potential transactions. Caller needs to save them to context.
    static func parseCSV(url: URL, context: ModelContext, categories: [Category]) throws -> [Transaction] {
        let content = try String(contentsOf: url)
        var rows = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        guard let headerRow = rows.first else { return [] }
        rows.removeFirst()
        
        // Dynamic Column Mapping
        let headers = headerRow.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        
        let dateIndex = headers.firstIndex(where: { $0.contains("date") }) ?? 0
        let noteIndex = headers.firstIndex(where: { $0.contains("note") }) ?? 1
        let amountIndex = headers.firstIndex(where: { $0.contains("amount") }) ?? 2
        let currencyIndex = headers.firstIndex(where: { $0.contains("currency") }) ?? 3
        let typeIndex = headers.firstIndex(where: { $0.contains("type") }) ?? 4
        let categoryIndex = headers.firstIndex(where: { $0.contains("category") }) ?? 5
        
        var transactions: [Transaction] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short // Matches .numeric formatted export
        
        // Fallback parser
        let isoFormatter = ISO8601DateFormatter()
        
        for row in rows {
            let columns = row.components(separatedBy: ",")
            let maxIndex = columns.count - 1
            
            // Helper to get safe value
            func getValue(at index: Int) -> String {
                if index <= maxIndex {
                    return columns[index].trimmingCharacters(in: .whitespaces)
                }
                return ""
            }
            
            if columns.count >= 3 { // Minimal requirement: Date, Amount at least
                let dateString = getValue(at: dateIndex)
                let note = getValue(at: noteIndex)
                let amountString = getValue(at: amountIndex)
                let currencyString = getValue(at: currencyIndex)
                let typeString = getValue(at: typeIndex)
                let categoryName = getValue(at: categoryIndex)
                
                // Parse Date
                var date = dateFormatter.date(from: dateString) ?? Date()
                if date == Date(), let isoDate = isoFormatter.date(from: dateString) {
                     date = isoDate
                }
                
                // Parse Amount
                let amount = Decimal(string: amountString) ?? 0
                
                // Parse Currency
                let currency: CurrencyType = currencyString.lowercased().contains("secondary") ? .secondary : .primary
                
                // Parse Type
                let type: TransactionType = typeString.lowercased().contains("income") ? .income : .expense
                
                // Find or Match Category
                let category = categories.first(where: { $0.name.lowercased() == categoryName.lowercased() })
                
                let transaction = Transaction(
                    date: date,
                    note: note,
                    categoryId: category?.id,
                    type: type,
                    currency: currency,
                    amount: amount
                )
                transactions.append(transaction)
            }
        }
        
        return transactions
    }
}

// MARK: - CSV Import Sheet
struct CSVImportSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [Category]
    @State private var importedTransactions: [Transaction] = []
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showFilePicker = true
    
    var body: some View {
        NavigationStack {
            VStack {
                if isImporting {
                    ProgressView("Importing...")
                } else if !importedTransactions.isEmpty {
                    List {
                        Text("Found \(importedTransactions.count) transactions")
                            .font(.headline)
                        ForEach(importedTransactions.prefix(5)) { t in
                            HStack {
                                Text(t.date.formatted(date: .numeric, time: .omitted))
                                Text(t.note).lineLimit(1)
                                Spacer()
                                Text(t.amount.formatted(.number.precision(.fractionLength(2))))
                            }
                        }
                        if importedTransactions.count > 5 { Text("...") }
                    }
                    Button("Confirm Import") { confirmImport() }
                        .buttonStyle(.borderedProminent)
                        .padding()
                } else {
                    ContentUnavailableView("Select a CSV file", systemImage: "doc.text")
                }
            }
            .navigationTitle("Import CSV")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .primaryAction) {
                     if importedTransactions.isEmpty { Button("Select File") { showFilePicker = true } }
                }
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                handleFileSelection(result)
            }
        }
    }
    
    private func handleFileSelection(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                importedTransactions = try CSVManager.parseCSV(url: url, context: modelContext, categories: categories)
                if importedTransactions.isEmpty { importError = "No transactions found" }
            }
        } catch { importError = error.localizedDescription }
    }
    
    private func confirmImport() {
        isImporting = true
        Task {
            for t in importedTransactions { modelContext.insert(t) }
            try? modelContext.save()
            isPresented = false
        }
    }
}
