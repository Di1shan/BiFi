import Foundation
import SwiftData

public struct CSVManager {
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
                    amount: amount,
                    type: type,
                    currency: currency,
                    categoryId: category?.id,
                    note: note
                )
                transactions.append(transaction)
            }
        }
        
        return transactions
    }
}
