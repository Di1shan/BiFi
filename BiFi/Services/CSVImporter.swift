import Foundation

// MARK: - CSV Parser
struct CSVParser {
    
    struct ParsedTransaction {
        let date: Date
        let description: String
        let categoryName: String
        let amount: Decimal
    }
    
    struct ParseResult {
        let transactions: [ParsedTransaction]
        let errors: [String]
        let skippedRows: Int
    }
    
    /// Parse CSV content with format: DATE, Description, CATEGORY, AMOUNT
    /// Date format expected: dd/mm/yyyy or d/m/yyyy
    static func parse(csvContent: String, skipHeader: Bool = true) -> ParseResult {
        var transactions: [ParsedTransaction] = []
        var errors: [String] = []
        var skippedRows = 0
        
        let rows = csvContent.components(separatedBy: .newlines)
        let startIndex = skipHeader ? 1 : 0
        
        for (index, row) in rows.enumerated() {
            // Skip header row if needed
            if index < startIndex { continue }
            
            // Skip empty rows
            let trimmedRow = row.trimmingCharacters(in: .whitespaces)
            if trimmedRow.isEmpty { continue }
            
            // Skip "Total" row or summary rows
            if trimmedRow.lowercased().hasPrefix("total") { continue }
            
            // Parse the row
            let columns = parseCSVRow(trimmedRow)
            
            // Expect at least 4 columns: DATE, Description, CATEGORY, AMOUNT
            if columns.count < 4 {
                errors.append("Row \(index + 1): Not enough columns (expected 4, got \(columns.count))")
                skippedRows += 1
                continue
            }
            
            // Parse date (column 0)
            guard let date = parseDate(columns[0]) else {
                errors.append("Row \(index + 1): Invalid date '\(columns[0])'")
                skippedRows += 1
                continue
            }
            
            // Parse description (column 1)
            let description = columns[1].trimmingCharacters(in: .whitespaces)
            
            // Parse category (column 2)
            let categoryName = columns[2].trimmingCharacters(in: .whitespaces)
            
            // Parse amount (column 3)
            guard let amount = parseAmount(columns[3]) else {
                errors.append("Row \(index + 1): Invalid amount '\(columns[3])'")
                skippedRows += 1
                continue
            }
            
            // Skip zero amounts
            if amount == 0 {
                skippedRows += 1
                continue
            }
            
            let transaction = ParsedTransaction(
                date: date,
                description: description,
                categoryName: categoryName,
                amount: amount
            )
            transactions.append(transaction)
        }
        
        return ParseResult(transactions: transactions, errors: errors, skippedRows: skippedRows)
    }
    
    /// Parse a single CSV row, handling quoted values
    private static func parseCSVRow(_ row: String) -> [String] {
        var result: [String] = []
        var currentValue = ""
        var insideQuotes = false
        
        for char in row {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                result.append(currentValue)
                currentValue = ""
            } else {
                currentValue.append(char)
            }
        }
        result.append(currentValue)
        
        return result
    }
    
    /// Parse date in dd/mm/yyyy or d/m/yyyy format
    private static func parseDate(_ dateString: String) -> Date? {
        let trimmed = dateString.trimmingCharacters(in: .whitespaces)
        
        let formatters: [DateFormatter] = [
            createFormatter("dd/MM/yyyy"),
            createFormatter("d/M/yyyy"),
            createFormatter("dd/M/yyyy"),
            createFormatter("d/MM/yyyy"),
            createFormatter("yyyy-MM-dd"),
            createFormatter("MM/dd/yyyy"),
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        
        return nil
    }
    
    private static func createFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
    
    /// Parse amount, handling various formats
    private static func parseAmount(_ amountString: String) -> Decimal? {
        var trimmed = amountString.trimmingCharacters(in: .whitespaces)
        
        // Remove currency symbols
        trimmed = trimmed.replacingOccurrences(of: "Rs", with: "")
        trimmed = trimmed.replacingOccurrences(of: "LKR", with: "")
        trimmed = trimmed.replacingOccurrences(of: "AUD", with: "")
        trimmed = trimmed.replacingOccurrences(of: "$", with: "")
        trimmed = trimmed.replacingOccurrences(of: "A$", with: "")
        trimmed = trimmed.trimmingCharacters(in: .whitespaces)
        
        // Remove thousand separators (comma)
        trimmed = trimmed.replacingOccurrences(of: ",", with: "")
        
        // Handle negative amounts in parentheses
        if trimmed.hasPrefix("(") && trimmed.hasSuffix(")") {
            trimmed = "-" + trimmed.dropFirst().dropLast()
        }
        
        return Decimal(string: trimmed)
    }
}

// MARK: - CSV Importer
class CSVImporter {
    
    struct ImportResult {
        let imported: Int
        let skipped: Int
        let newCategories: [String]
        let errors: [String]
    }
    
    /// Import parsed transactions into the database
    static func importTransactions(
        _ parsed: [CSVParser.ParsedTransaction],
        into modelContext: Any, // ModelContext
        existingCategories: [Category],
        currency: CurrencyType,
        createNewCategories: Bool = true
    ) -> ImportResult {
        guard let context = modelContext as? SwiftData.ModelContext else {
            return ImportResult(imported: 0, skipped: parsed.count, newCategories: [], errors: ["Invalid model context"])
        }
        
        var imported = 0
        let skipped = 0
        var newCategoryNames: [String] = []
        var errors: [String] = []
        var categoryCache: [String: Category] = [:]
        
        // Build category lookup cache (case-insensitive)
        for category in existingCategories {
            categoryCache[category.name.lowercased()] = category
        }
        
        for parsed in parsed {
            // Find or create category
            let categoryKey = parsed.categoryName.lowercased()
            var category: Category? = categoryCache[categoryKey]
            
            if category == nil && createNewCategories && !parsed.categoryName.isEmpty {
                // Create new category
                let newCategory = Category(
                    name: parsed.categoryName,
                    icon: "tag.fill",
                    colorHex: ColorHelper.randomCategoryColor(),
                    isDefault: false,
                    sortOrder: existingCategories.count + newCategoryNames.count
                )
                context.insert(newCategory)
                categoryCache[categoryKey] = newCategory
                category = newCategory
                newCategoryNames.append(parsed.categoryName)
            }
            
            // Create transaction (all imported are expenses)
            let transaction = Transaction(
                date: parsed.date,
                note: parsed.description,
                categoryId: category?.id,
                type: .expense,
                currency: currency,
                amount: abs(parsed.amount) // Ensure positive
            )
            
            context.insert(transaction)
            imported += 1
        }
        
        // Save changes
        do {
            try context.save()
        } catch {
            errors.append("Failed to save: \(error.localizedDescription)")
        }
        
        return ImportResult(
            imported: imported,
            skipped: skipped,
            newCategories: newCategoryNames,
            errors: errors
        )
    }
}

import SwiftData
