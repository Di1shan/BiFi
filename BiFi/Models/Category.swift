import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var isDefault: Bool
    var sortOrder: Int
    
    var isExpenseEnabled: Bool = true

    var isIncomeEnabled: Bool = false
    var isSavingsEnabled: Bool = false
    
    @Relationship(deleteRule: .nullify) var group: CategoryGroup?
    
    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        colorHex: String,
        isDefault: Bool = false,
        isExpenseEnabled: Bool = true,

        isIncomeEnabled: Bool = false,
        isSavingsEnabled: Bool = false,
        sortOrder: Int = 0,
        group: CategoryGroup? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isDefault = isDefault
        self.isExpenseEnabled = isExpenseEnabled

        self.isIncomeEnabled = isIncomeEnabled
        self.isSavingsEnabled = isSavingsEnabled
        self.sortOrder = sortOrder
        self.group = group
    }
}

@Model
final class CategoryGroup {
    var id: UUID
    var name: String
    var sortOrder: Int
    var isSystem: Bool
    @Relationship(deleteRule: .nullify, inverse: \Category.group) var categories: [Category]?
    
    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int = 0,
        isSystem: Bool = false
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.isSystem = isSystem
        self.categories = []
    }
}

// MARK: - Default Categories
extension Category {
    static var defaultCategories: [Category] {
        [
            Category(name: "Food", icon: "fork.knife", colorHex: "#FF6B6B", isDefault: true, isExpenseEnabled: true, isIncomeEnabled: false, isSavingsEnabled: false, sortOrder: 0),
            Category(name: "Transport", icon: "car.fill", colorHex: "#4ECDC4", isDefault: true, isExpenseEnabled: true, isIncomeEnabled: false, isSavingsEnabled: false, sortOrder: 1),
            Category(name: "Bills", icon: "doc.text.fill", colorHex: "#45B7D1", isDefault: true, isExpenseEnabled: true, isIncomeEnabled: false, isSavingsEnabled: false, sortOrder: 2),
            Category(name: "Entertainment", icon: "gamecontroller.fill", colorHex: "#96CEB4", isDefault: true, isExpenseEnabled: true, isIncomeEnabled: false, isSavingsEnabled: false, sortOrder: 3),
            Category(name: "Health", icon: "heart.fill", colorHex: "#FF8A80", isDefault: true, isExpenseEnabled: true, isIncomeEnabled: false, isSavingsEnabled: false, sortOrder: 4),
            Category(name: "Shopping", icon: "bag.fill", colorHex: "#DDA0DD", isDefault: true, isExpenseEnabled: true, isIncomeEnabled: false, isSavingsEnabled: false, sortOrder: 5),
            Category(name: "Salary", icon: "banknote.fill", colorHex: "#98D8C8", isDefault: true, isExpenseEnabled: false, isIncomeEnabled: true, isSavingsEnabled: false, sortOrder: 6),
            Category(name: "Other", icon: "ellipsis.circle.fill", colorHex: "#B8B8B8", isDefault: true, isExpenseEnabled: true, isIncomeEnabled: true, isSavingsEnabled: false, sortOrder: 7)
        ]
    }
    
    static func salaryCategory(from categories: [Category]) -> Category? {
        categories.first { $0.name == "Salary" }
    }
}
