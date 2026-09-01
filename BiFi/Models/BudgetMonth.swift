import Foundation
import SwiftData

@Model
final class BudgetMonth {
    var id: UUID
    var monthKey: String // YYYY-MM format
    @Attribute var primaryMonthlyBudget: Decimal
    @Attribute var secondaryMonthlyBudget: Decimal
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        monthKey: String,
        primaryMonthlyBudget: Decimal = 0,
        secondaryMonthlyBudget: Decimal = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.monthKey = monthKey
        self.primaryMonthlyBudget = primaryMonthlyBudget
        self.secondaryMonthlyBudget = secondaryMonthlyBudget
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class CategoryBudget {
    var id: UUID
    var categoryId: UUID
    var monthKey: String
    var primaryLimit: Decimal
    var secondaryLimit: Decimal
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        categoryId: UUID,
        monthKey: String,
        primaryLimit: Decimal = 0,
        secondaryLimit: Decimal = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.categoryId = categoryId
        self.monthKey = monthKey
        self.primaryLimit = primaryLimit
        self.secondaryLimit = secondaryLimit
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
