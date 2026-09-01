import SwiftUI
import SwiftData

// MARK: - CSV Export View
struct CSVExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var transactions: [Transaction]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var settings: [AppSettings]
    
    @State private var selectedDate: Date = Date()
    @State private var selectedCurrency: CurrencyFilter = .all
    @State private var includeIncome = false
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportedFileURL: URL?
    @State private var exportError: String?
    
    private var currentSettings: AppSettings? {
        settings.first
    }
    
    private var primaryCode: String {
        currentSettings?.primaryCurrencyCode ?? "LKR"
    }
    
    private var secondaryCode: String {
        currentSettings?.secondaryCurrencyCode ?? "AUD"
    }
    
    private var selectedMonthKey: String {
        MonthHelper.monthKey(from: selectedDate)
    }
    
    private var filteredTransactions: [Transaction] {
        let monthStart = MonthHelper.startOfMonth(for: selectedDate)
        let monthEnd = MonthHelper.endOfMonth(for: selectedDate)
        
        return transactions.filter { tx in
            // Filter by date
            guard tx.date >= monthStart && tx.date <= monthEnd else { return false }
            
            // Filter by type
            if !includeIncome && tx.type == .income { return false }
            
            // Filter by currency
            switch selectedCurrency {
            case .all:
                return true
            case .primary:
                return tx.currency == .primary
            case .secondary:
                return tx.currency == .secondary
            }
        }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Month Selector
                    monthSelector
                    
                    // Filter Options
                    filterOptions
                    
                    // Preview
                    previewSection
                    
                    // Export Button
                    exportButton
                    
                    // Error Message
                    if let error = exportError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Export CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
    
    // MARK: - Month Selector
    private var monthSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Month")
                .font(.headline)
            
            HStack {
                Button {
                    HapticsHelper.shared.impact(.light)
                    selectedDate = MonthHelper.previousMonth(from: selectedDate)
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                Text(MonthHelper.monthTitle(from: selectedDate))
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    HapticsHelper.shared.impact(.light)
                    selectedDate = MonthHelper.nextMonth(from: selectedDate)
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Filter Options
    private var filterOptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Options")
                .font(.headline)
            
            // Currency Filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Currency")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("Currency", selection: $selectedCurrency) {
                    Text("All").tag(CurrencyFilter.all)
                    Text(primaryCode).tag(CurrencyFilter.primary)
                    Text(secondaryCode).tag(CurrencyFilter.secondary)
                }
                .pickerStyle(.segmented)
            }
            
            // Include Income Toggle
            Toggle(isOn: $includeIncome) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Include Income")
                        .font(.subheadline)
                    Text("Export both income and expenses")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Preview Section
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preview")
                    .font(.headline)
                
                Spacer()
                
                Text("\(filteredTransactions.count) transactions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if filteredTransactions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    
                    Text("No transactions to export")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                // Show first 5 transactions
                VStack(spacing: 8) {
                    ForEach(Array(filteredTransactions.prefix(5)), id: \.id) { tx in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tx.note.isEmpty ? categoryName(for: tx.categoryId) : tx.note)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                
                                Text(formatDate(tx.date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formatAmount(tx))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(tx.type == .income ? .green : .primary)
                                
                                Text(categoryName(for: tx.categoryId))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        if tx.id != filteredTransactions.prefix(5).last?.id {
                            Divider()
                        }
                    }
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                if filteredTransactions.count > 5 {
                    Text("...and \(filteredTransactions.count - 5) more transactions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Summary
                let expenses = filteredTransactions.filter { $0.type == .expense }
                let income = filteredTransactions.filter { $0.type == .income }
                
                HStack {
                    if !expenses.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Expenses")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(expenses.count)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Spacer()
                    
                    if !income.isEmpty {
                        VStack(alignment: .trailing) {
                            Text("Income")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(income.count)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Export Button
    private var exportButton: some View {
        Button {
            exportToCSV()
        } label: {
            HStack {
                if isExporting {
                    LoadingDotsView(color: .white)
                } else {
                    Image(systemName: "square.and.arrow.up.fill")
                }
                Text(isExporting ? "Exporting..." : "Export \(filteredTransactions.count) Transactions")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(filteredTransactions.isEmpty ? Color.gray : Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(BounceButtonStyle())
        .disabled(filteredTransactions.isEmpty || isExporting)
    }
    
    // MARK: - Helpers
    private func categoryName(for categoryId: UUID?) -> String {
        guard let id = categoryId,
              let category = categories.first(where: { $0.id == id }) else {
            return "Uncategorized"
        }
        return category.name
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
    
    private func formatAmount(_ tx: Transaction) -> String {
        let code = tx.currency == .primary ? primaryCode : secondaryCode
        return MoneyFormatter.format(tx.amount, currencyCode: code)
    }
    
    // MARK: - Export Logic
    private func exportToCSV() {
        isExporting = true
        exportError = nil
        HapticsHelper.shared.impact()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let csv = generateCSV()
            
            // Create temporary file
            let fileName = "DualBudget_\(selectedMonthKey).csv"
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            do {
                try csv.write(to: fileURL, atomically: true, encoding: .utf8)
                
                DispatchQueue.main.async {
                    self.exportedFileURL = fileURL
                    self.isExporting = false
                    self.showShareSheet = true
                    HapticsHelper.shared.notification(.success)
                }
            } catch {
                DispatchQueue.main.async {
                    self.exportError = "Failed to export: \(error.localizedDescription)"
                    self.isExporting = false
                    HapticsHelper.shared.notification(.error)
                }
            }
        }
    }
    
    private func generateCSV() -> String {
        var lines: [String] = []
        
        // Header
        lines.append("DATE,Description,CATEGORY,TYPE,CURRENCY,AMOUNT")
        
        // Data rows
        for tx in filteredTransactions {
            let date = formatDate(tx.date)
            let description = escapeCSV(tx.note)
            let category = escapeCSV(categoryName(for: tx.categoryId))
            let type = tx.type == .income ? "Income" : "Expense"
            let currency = tx.currency == .primary ? primaryCode : secondaryCode
            let amount = "\(tx.amount)"
            
            lines.append("\(date),\(description),\(category),\(type),\(currency),\(amount)")
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    CSVExportView()
        .modelContainer(for: [Transaction.self, Category.self, BudgetMonth.self, AppSettings.self], inMemory: true)
}
