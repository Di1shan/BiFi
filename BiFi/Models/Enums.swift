import Foundation

// MARK: - TransactionType
enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case income
    case expense
    case savings
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .income: return "Income"
        case .expense: return "Expense"
        case .savings: return "Savings"
        }
    }
    
    var icon: String {
        switch self {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .savings: return "piggy.bank.fill"
        }
    }
}



// MARK: - Currency Type
enum CurrencyType: String, Codable, CaseIterable, Identifiable {
    case primary
    case secondary
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .primary: return "Primary"
        case .secondary: return "Secondary"
        }
    }
}

// MARK: - Appearance Mode
enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

// MARK: - Currency Filter
enum CurrencyFilter: String, CaseIterable, Identifiable {
    case all
    case primary
    case secondary
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .primary: return "Primary"
        case .secondary: return "Secondary"
        }
    }
}

// MARK: - Type Filter
enum TypeFilter: String, CaseIterable, Identifiable {
    case all
    case income
    case expense
    case savings
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .income: return "Income"
        case .expense: return "Expense"
        case .savings: return "Savings"
        }
    }
}
