import Foundation

// MARK: - Money Formatter
struct MoneyFormatter {
    
    /// Format decimal amount with currency code (e.g., "LKR 1,234.00")
    static func format(_ amount: Decimal, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        
        let formattedNumber = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(currencyCode) \(formattedNumber)"
    }
    
    /// Format decimal amount with sign and currency code
    static func formatWithSign(_ amount: Decimal, currencyCode: String, isPositive: Bool) -> String {
        let sign = isPositive ? "+" : "-"
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        
        let absAmount = abs(amount)
        let formattedNumber = formatter.string(from: absAmount as NSDecimalNumber) ?? "0.00"
        return "\(sign)\(currencyCode) \(formattedNumber)"
    }
    
    /// Parse string to Decimal
    static func parse(_ string: String) -> Decimal? {
        let cleanString = string.replacingOccurrences(of: ",", with: "")
        return Decimal(string: cleanString)
    }
}

// MARK: - Decimal Extensions
extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
    
    static func abs(_ value: Decimal) -> Decimal {
        value < 0 ? -value : value
    }
}

func abs(_ value: Decimal) -> Decimal {
    Decimal.abs(value)
}
