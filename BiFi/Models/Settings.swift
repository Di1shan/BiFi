import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID
    var primaryCurrencyCode: String
    var secondaryCurrencyCode: String
    var appearance: AppearanceMode
    var hapticsEnabled: Bool
    var appLockEnabled: Bool
    var dashboardWidgetOrder: [String] = []
    var financialMonthStartDay: Int = 1
    var financialMonthEnabled: Bool = false
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        primaryCurrencyCode: String = "LKR",
        secondaryCurrencyCode: String = "AUD",
        appearance: AppearanceMode = .system,
        hapticsEnabled: Bool = true,
        appLockEnabled: Bool = false,
        dashboardWidgetOrder: [String] = [],
        financialMonthStartDay: Int = 1,
        financialMonthEnabled: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.primaryCurrencyCode = primaryCurrencyCode
        self.secondaryCurrencyCode = secondaryCurrencyCode
        self.appearance = appearance
        self.hapticsEnabled = hapticsEnabled
        self.appLockEnabled = appLockEnabled
        self.dashboardWidgetOrder = dashboardWidgetOrder
        self.financialMonthStartDay = financialMonthStartDay
        self.financialMonthEnabled = financialMonthEnabled
        self.updatedAt = updatedAt
    }
    
    var effectiveFinancialStartDay: Int {
        financialMonthEnabled ? financialMonthStartDay : 1
    }
}

// MARK: - Common Currency Codes
extension AppSettings {
    static let commonCurrencyCodes = [
        "LKR", "AUD", "USD", "EUR", "GBP", "JPY", "CNY", "INR", "CAD", "NZD",
        "SGD", "HKD", "CHF", "SEK", "NOK", "DKK", "KRW", "MYR", "THB", "PHP"
    ]
}
