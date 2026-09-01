import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CSVImportSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [Category]
    
    @State private var importedTransactions: [Transaction] = []
    @State private var showingPreview = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showFilePicker = true
    
    var body: some View {
        NavigationStack {
            VStack {
                if isImporting {
                    ProgressView("Importing...")
                        .scaleEffect(1.2)
                } else if !importedTransactions.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.green)
                            
                            Text("Ready to Import")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .padding(.bottom)
                        
                        Text("Found **\(importedTransactions.count)** transactions.")
                        
                        Text("Preview first 5:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        List {
                            ForEach(importedTransactions.prefix(5)) { transaction in
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(transaction.date.formatted(date: .numeric, time: .omitted))
                                        Spacer()
                                        Text(MoneyFormatter.format(transaction.amount, currencyCode: transaction.currency == .primary ? "LKR" : "AUD"))
                                    }
                                    Text(transaction.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .frame(maxHeight: 300)
                        
                        Spacer()
                        
                        Button {
                            confirmImport()
                        } label: {
                            Text("Import \(importedTransactions.count) Transactions")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.primaryGradient)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                } else {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "doc.text",
                        description: Text("Select a CSV file to import transactions.")
                    )
                }
            }
            .navigationTitle("Import CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
                
                if importedTransactions.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Select File") {
                            showFilePicker = true
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .alert("Import Error", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK") { }
            } message: {
                Text(importError ?? "Unknown error")
            }
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                
                let transactions = try CSVManager.parseCSV(url: url, context: modelContext, categories: categories)
                
                if transactions.isEmpty {
                    importError = "No valid transactions found in the file."
                } else {
                    withAnimation {
                        self.importedTransactions = transactions
                    }
                }
            }
        } catch {
            importError = "Failed to read file: \(error.localizedDescription)"
        }
    }
    
    private func confirmImport() {
        isImporting = true
        
        // Run on background to avoid UI freeze
        Task {
            // Main thread for Core Data / SwiftData updates usually
            // but we can batch insert? SwiftData isn't thread safe cross-actor easily.
            // Let's keep it simple on MainActor for now, it's fast enough.
            
            do {
                for transaction in importedTransactions {
                    modelContext.insert(transaction)
                }
                try modelContext.save()
                
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
                
                isPresented = false
                HapticsHelper.shared.notification(.success)
            } catch {
                importError = "Failed to save: \(error.localizedDescription)"
                isImporting = false
            }
        }
    }
}
