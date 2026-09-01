import Foundation
import SwiftData

// MARK: - Balance Calculator
// MARK: - Balance Calculator
struct BalanceCalculator {
    
    /// Efficiently sum amounts for a given type and currency from a PRE-FILTERED list
    static func calculateTotal(
        transactions: [Transaction],
        type: TransactionType,
        currency: CurrencyType? = nil
    ) -> Decimal {
        transactions.reduce(Decimal(0)) { result, transaction in
            if transaction.type == type && (currency == nil || transaction.currency == currency) {
                return result + transaction.amount
            }
            return result
        }
    }
    
    /// Calculate opening balance (sum of all transactions before the start date)
    static func openingBalance(
        transactions: [Transaction],
        currency: CurrencyType,
        before date: Date
    ) -> Decimal {
        return transactions
            .filter { $0.currency == currency && $0.date < date }
            .reduce(Decimal(0)) { result, transaction in
                switch transaction.type {
                case .income:
                    return result + transaction.amount
                case .expense, .savings:
                    return result - transaction.amount
                }
            }
    }
    
    // Backward compatibility for existing monthKey usages (if any remain temporarily)
    static func openingBalance(transactions: [Transaction], currency: CurrencyType, monthKey: String) -> Decimal {
        guard let start = MonthHelper.startOfMonth(from: monthKey) else { return 0 }
        return openingBalance(transactions: transactions, currency: currency, before: start)
    }
    
    /// Calculate sum of income within a period
    static func periodIncome(
        transactions: [Transaction],
        currency: CurrencyType,
        start: Date,
        endExclusive: Date
    ) -> Decimal {
        return transactions
            .filter { 
                $0.currency == currency && 
                $0.type == .income && 
                $0.date >= start && 
                $0.date < endExclusive 
            }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    // Backward compatibility
    static func monthIncome(transactions: [Transaction], currency: CurrencyType, monthKey: String) -> Decimal {
        guard let start = MonthHelper.startOfMonth(from: monthKey),
              let end = MonthHelper.endOfMonth(from: monthKey) else { return 0 }
        // Note: MonthHelper.endOfMonth returns end of day, so we adjust for exclusive check if needed,
        // but existing logic used <= endOfMonth.
        // My new method uses < endExclusive.
        // Let's keep existing behavior for legacy call:
        return transactions
            .filter {
                $0.currency == currency &&
                $0.type == .income &&
                $0.date >= start &&
                $0.date <= end
            }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    /// Calculate sum of expenses within a period
    static func periodExpense(
        transactions: [Transaction],
        currency: CurrencyType,
        start: Date,
        endExclusive: Date
    ) -> Decimal {
        return transactions
            .filter { 
                $0.currency == currency && 
                ($0.type == .expense || $0.type == .savings) && 
                $0.date >= start && 
                $0.date < endExclusive 
            }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    // Backward compatibility
    static func monthExpense(transactions: [Transaction], currency: CurrencyType, monthKey: String) -> Decimal {
        guard let start = MonthHelper.startOfMonth(from: monthKey),
              let end = MonthHelper.endOfMonth(from: monthKey) else { return 0 }
        return transactions
            .filter {
                $0.currency == currency &&
                ($0.type == .expense || $0.type == .savings) &&
                $0.date >= start &&
                $0.date <= end
            }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    /// Calculate net for a period (income - expense)
    static func periodNet(
        transactions: [Transaction],
        currency: CurrencyType,
        start: Date,
        endExclusive: Date
    ) -> Decimal {
        let income = periodIncome(transactions: transactions, currency: currency, start: start, endExclusive: endExclusive)
        let expense = periodExpense(transactions: transactions, currency: currency, start: start, endExclusive: endExclusive)
        return income - expense
    }
    
    /// Calculate current in-hand balance (running total up to now)
    static func currentInHand(
        transactions: [Transaction],
        currency: CurrencyType
    ) -> Decimal {
        let now = Date()
        return transactions
            .filter { $0.currency == currency && $0.date <= now }
            .reduce(Decimal(0)) { result, transaction in
                switch transaction.type {
                case .income:
                    return result + transaction.amount
                case .expense, .savings:
                    return result - transaction.amount
                }
            }
    }
    
    /// Get category breakdown for expenses
    static func categoryBreakdown(
        transactions: [Transaction],
        categories: [Category],
        currency: CurrencyType?,
        start: Date? = nil,
        endExclusive: Date? = nil
    ) -> [(category: Category?, amount: Decimal, percentage: Double)] {
        let filteredTransactions = transactions.filter { transaction in
            (transaction.type == .expense || transaction.type == .savings) &&
            (currency == nil || transaction.currency == currency) &&
            (start == nil || transaction.date >= start!) &&
            (endExclusive == nil || transaction.date < endExclusive!)
        }
        
        let totalExpense = filteredTransactions.reduce(Decimal(0)) { $0 + $1.amount }
        guard totalExpense > 0 else { return [] }
        
        var categoryTotals: [UUID?: Decimal] = [:]
        
        for transaction in filteredTransactions {
            categoryTotals[transaction.categoryId, default: 0] += transaction.amount
        }
        
        let breakdown = categoryTotals.map { (categoryId, amount) -> (Category?, Decimal, Double) in
            let category = categories.first { $0.id == categoryId }
            let percentage = (amount / totalExpense).doubleValue * 100
            return (category, amount, percentage)
        }
        .sorted { $0.1 > $1.1 }
        
        return breakdown
    }
    
    // Legacy support for Breakdown
    static func categoryBreakdown(
        transactions: [Transaction],
        categories: [Category],
        currency: CurrencyType?,
        monthKey: String
    ) -> [(category: Category?, amount: Decimal, percentage: Double)] {
        guard let start = MonthHelper.startOfMonth(from: monthKey),
              let end = MonthHelper.endOfMonth(from: monthKey) else { return [] }
        // Adapt end inclusive to exclusive range roughly by adding 1 second or just using the boolean logic inside?
        // Actually the new method uses < endExclusive.
        // endOfMonth returns YYYY-MM-DD 23:59:59.
        // So endExclusive should be startOfNextMonth.
        
        // Let's just reimplement legacy logic cleanly here to avoid issues:
        let filtered = transactions.filter {
            ($0.type == .expense || $0.type == .savings) &&
            (currency == nil || $0.currency == currency) &&
            $0.date >= start &&
            $0.date <= end
        }
        
        let totalExpense = filtered.reduce(Decimal(0)) { $0 + $1.amount }
        guard totalExpense > 0 else { return [] }
        
        var categoryTotals: [UUID?: Decimal] = [:]
        for transaction in filtered {
            categoryTotals[transaction.categoryId, default: 0] += transaction.amount
        }
        return categoryTotals.map { (categoryId, amount) -> (Category?, Decimal, Double) in
            let category = categories.first { $0.id == categoryId }
            let percentage = (amount / totalExpense).doubleValue * 100
            return (category, amount, percentage)
        }.sorted { $0.1 > $1.1 }
    }
}
