import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID
    var date: Date
    var note: String
    var categoryId: UUID?
    var type: TransactionType
    var currency: CurrencyType
    @Attribute var amount: Decimal
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        note: String = "",
        categoryId: UUID? = nil,
        type: TransactionType,
        currency: CurrencyType,
        amount: Decimal,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.note = note
        self.categoryId = categoryId
        self.type = type
        self.currency = currency
        self.amount = amount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
