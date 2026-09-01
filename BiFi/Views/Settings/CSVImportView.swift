import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - CSV Import View
struct CSVImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var settings: [AppSettings]
    
    @State private var isImporting = false
    @State private var importResult: CSVImporter.ImportResult?
    @State private var parseResult: CSVParser.ParseResult?
    @State private var selectedCurrency: CurrencyType = .primary
    @State private var showingFilePicker = false
    @State private var showingPreview = false
    @State private var csvContent: String = ""
    @State private var fileName: String = ""
    @State private var showingResults = false
    @State private var isProcessing = false
    
    private var currentSettings: AppSettings? {
        settings.first
    }
    
    private var primaryCode: String {
        currentSettings?.primaryCurrencyCode ?? "LKR"
    }
    
    private var secondaryCode: String {
        currentSettings?.secondaryCurrencyCode ?? "AUD"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Instructions
                    instructionsCard
                    
                    // Currency Selection
                    currencyPicker
                    
                    // File Selection
                    fileSelectionCard
                    
                    // Preview Section
                    if let result = parseResult, !result.transactions.isEmpty {
                        previewCard(result)
                    }
                    
                    // Import Button
                    if parseResult != nil && parseResult!.transactions.count > 0 {
                        importButton
                    }
                    
                    // Results
                    if let result = importResult {
                        resultsCard(result)
                    }
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Import CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
    }
    
    // MARK: - Instructions Card
    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("CSV Format", systemImage: "doc.text")
                .font(.headline)
            
            Text("Your CSV file should have these columns:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                formatRow(column: "A", name: "DATE", example: "31/12/2025")
                formatRow(column: "B", name: "Description", example: "Lunch at cafe")
                formatRow(column: "C", name: "CATEGORY", example: "Food")
                formatRow(column: "D", name: "AMOUNT", example: "1500")
            }
            .padding()
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text("• First row is skipped (headers)\n• All imported items will be expenses\n• New categories will be created automatically")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func formatRow(column: String, name: String, example: String) -> some View {
        HStack {
            Text(column)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 24)
                .padding(4)
                .background(Color.accentColor.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .leading)
            
            Text(example)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Currency Picker
    private var currencyPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import Currency")
                .font(.headline)
            
            Picker("Currency", selection: $selectedCurrency) {
                Text(primaryCode).tag(CurrencyType.primary)
                Text(secondaryCode).tag(CurrencyType.secondary)
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - File Selection Card
    private var fileSelectionCard: some View {
        VStack(spacing: 16) {
            if fileName.isEmpty {
                Button {
                    showingFilePicker = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        
                        Text("Select CSV File")
                            .font(.headline)
                        
                        Text("Tap to browse files")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            } else {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    
                    VStack(alignment: .leading) {
                        Text(fileName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if let result = parseResult {
                            Text("\(result.transactions.count) expenses found")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        clearSelection()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                
                Button {
                    showingFilePicker = true
                } label: {
                    Text("Choose Different File")
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Preview Card
    private func previewCard(_ result: CSVParser.ParseResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preview")
                    .font(.headline)
                
                Spacer()
                
                Text("\(result.transactions.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Show first 5 transactions
            VStack(spacing: 8) {
                ForEach(Array(result.transactions.prefix(5).enumerated()), id: \.offset) { index, tx in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.description.isEmpty ? tx.categoryName : tx.description)
                                .font(.subheadline)
                                .lineLimit(1)
                            
                            Text(formatPreviewDate(tx.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(MoneyFormatter.format(tx.amount, currencyCode: selectedCurrency == .primary ? primaryCode : secondaryCode))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(tx.categoryName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if index < min(result.transactions.count, 5) - 1 {
                        Divider()
                    }
                }
            }
            .padding()
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            if result.transactions.count > 5 {
                Text("...and \(result.transactions.count - 5) more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Show errors if any
            if !result.errors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("⚠️ \(result.errors.count) parsing issues:")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    
                    ForEach(Array(result.errors.prefix(3)), id: \.self) { error in
                        Text("• \(error)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Import Button
    private var importButton: some View {
        Button {
            performImport()
        } label: {
            HStack {
                if isProcessing {
                    LoadingDotsView(color: .white)
                } else {
                    Image(systemName: "square.and.arrow.down.fill")
                }
                Text(isProcessing ? "Importing..." : "Import \(parseResult?.transactions.count ?? 0) Expenses")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isProcessing)
    }
    
    // MARK: - Results Card
    private func resultsCard(_ result: CSVImporter.ImportResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if result.errors.isEmpty {
                    AnimatedCheckmark(color: .green)
                        .frame(width: 30, height: 30)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.title2)
                        .shake(trigger: true)
                }
                
                Text(result.errors.isEmpty ? "Import Complete!" : "Import Complete with Issues")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                resultRow(label: "Imported", value: "\(result.imported)", color: .green)
                
                if result.skipped > 0 {
                    resultRow(label: "Skipped", value: "\(result.skipped)", color: .orange)
                }
                
                if !result.newCategories.isEmpty {
                    resultRow(label: "New Categories", value: "\(result.newCategories.count)", color: .blue)
                    
                    Text(result.newCategories.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 24)
                }
            }
            
            if !result.errors.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Errors:")
                        .font(.caption)
                        .foregroundStyle(.red)
                    
                    ForEach(result.errors, id: \.self) { error in
                        Text("• \(error)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(BounceButtonStyle())
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func resultRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Actions
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                csvContent = content
                fileName = url.lastPathComponent
                
                // Parse CSV
                parseResult = CSVParser.parse(csvContent: content, skipHeader: true)
                importResult = nil
                
                HapticsHelper.shared.notification(.success)
            } catch {
                HapticsHelper.shared.notification(.error)
            }
            
        case .failure:
            HapticsHelper.shared.notification(.error)
        }
    }
    
    private func clearSelection() {
        csvContent = ""
        fileName = ""
        parseResult = nil
        importResult = nil
    }
    
    private func performImport() {
        guard let parsed = parseResult?.transactions else { return }
        
        isProcessing = true
        HapticsHelper.shared.impact()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let result = CSVImporter.importTransactions(
                parsed,
                into: modelContext,
                existingCategories: categories,
                currency: selectedCurrency,
                createNewCategories: true
            )
            
            importResult = result
            isProcessing = false
            
            if result.errors.isEmpty {
                HapticsHelper.shared.notification(.success)
            } else {
                HapticsHelper.shared.notification(.warning)
            }
        }
    }
    
    private func formatPreviewDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    CSVImportView()
        .modelContainer(for: [Transaction.self, Category.self, BudgetMonth.self, AppSettings.self], inMemory: true)
}
