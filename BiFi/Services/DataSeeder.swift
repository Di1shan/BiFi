import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Data Seeder
/// Handles idempotent seeding of default data on first launch
final class DataSeeder {
    
    /// Seeds default data if not already present (idempotent)
    static func seedIfNeeded(modelContext: ModelContext) {
        seedSettingsIfNeeded(modelContext: modelContext)
        seedCategoriesIfNeeded(modelContext: modelContext)
        seedCategoryGroupsIfNeeded(modelContext: modelContext)
    }
    
    /// Creates AppSettings row if not present
    private static func seedSettingsIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<AppSettings>()
        
        do {
            let existingSettings = try modelContext.fetch(descriptor)
            if existingSettings.isEmpty {
                let settings = AppSettings()
                modelContext.insert(settings)
                try modelContext.save()
            }
        } catch {
            print("Error seeding settings: \(error)")
        }
    }
    
    /// Inserts default categories if none exist
    private static func seedCategoriesIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Category>()
        
        do {
            let existingCategories = try modelContext.fetch(descriptor)
            if existingCategories.isEmpty {
                for category in Category.defaultCategories {
                    modelContext.insert(category)
                }
                try modelContext.save()
            }
        } catch {
            print("Error seeding categories: \(error)")
        }
    }
    
    /// Seeds default category groups and assigns categories
    private static func seedCategoryGroupsIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<CategoryGroup>()
        
        do {
            let existingGroups = try modelContext.fetch(descriptor)
            
            // Map of Group Name -> Group Object
            var groupsMap: [String: CategoryGroup] = [:]
            
            if existingGroups.isEmpty {
                let defaultGroups = [
                    CategoryGroup(name: "Needs", sortOrder: 0, isSystem: true),
                    CategoryGroup(name: "Wants", sortOrder: 1, isSystem: true),
                    CategoryGroup(name: "Savings", sortOrder: 2, isSystem: true),
                    CategoryGroup(name: "Debts", sortOrder: 3, isSystem: true)
                ]
                
                for group in defaultGroups {
                    modelContext.insert(group)
                    groupsMap[group.name] = group
                }
                try modelContext.save()
            } else {
                for group in existingGroups {
                    groupsMap[group.name] = group
                }
            }
            
            // Assign Categories to Groups
            let categoryDescriptor = FetchDescriptor<Category>()
            let categories = try modelContext.fetch(categoryDescriptor)
            
            for category in categories {
                if category.group == nil {
                    switch category.name {
                    case "Food", "Transport", "Bills", "Health", "Rent", "Groceries":
                        category.group = groupsMap["Needs"]
                    case "Entertainment", "Shopping", "Dining Out", "Other":
                        category.group = groupsMap["Wants"]
                    case "Investment", "Emergency Fund":
                        category.group = groupsMap["Savings"]
                    case "Loans", "Credit Card":
                        category.group = groupsMap["Debts"]
                    case "Salary":
                        // Salary is income, usually doesn't need an expense group, or put in separate Income group?
                        // For now leave nil or create Income group?
                        // User specified: wants needs debts savings.
                        // Salary isn't an expense.
                        break
                    default:
                        category.group = groupsMap["Wants"] // Default to Wants
                    }
                }
            }
            try modelContext.save()
            
        } catch {
            print("Error seeding category groups: \(error)")
        }
    }
}

// MARK: - Backup DTOs
struct TransactionDTO: Codable {
    let id: UUID
    let date: Date
    let note: String
    let categoryId: UUID?
    let type: TransactionType
    let currency: CurrencyType
    let amount: Decimal
    let createdAt: Date
    let updatedAt: Date
}

struct CategoryDTO: Codable {
    let id: UUID
    let name: String
    let icon: String
    let colorHex: String
    let isDefault: Bool
    let sortOrder: Int
    let groupId: UUID?
    let isExpenseEnabled: Bool?
    let isIncomeEnabled: Bool?
    let isSavingsEnabled: Bool?
}

struct CategoryGroupDTO: Codable {
    let id: UUID
    let name: String
    let sortOrder: Int
    let isSystem: Bool
}

struct BudgetMonthDTO: Codable {
    let id: UUID
    let monthKey: String
    let primaryMonthlyBudget: Decimal
    let secondaryMonthlyBudget: Decimal
    let createdAt: Date
    let updatedAt: Date
}

struct CategoryBudgetDTO: Codable {
    let id: UUID
    let categoryId: UUID
    let monthKey: String
    let primaryLimit: Decimal
    let secondaryLimit: Decimal
    let createdAt: Date
    let updatedAt: Date
}

struct AppSettingsDTO: Codable {
    let id: UUID
    let primaryCurrencyCode: String
    let secondaryCurrencyCode: String
    let appearance: AppearanceMode
    let hapticsEnabled: Bool
    let appLockEnabled: Bool
    let dashboardWidgetOrder: [String]
    let financialMonthStartDay: Int? // Optional for backward compatibility
    let updatedAt: Date
}

struct BackupData: Codable {
    let version: Int
    let timestamp: Date
    let transactions: [TransactionDTO]
    let categories: [CategoryDTO]
    let groups: [CategoryGroupDTO]
    let budgetMonths: [BudgetMonthDTO]
    let categoryBudgets: [CategoryBudgetDTO]
    let settings: [AppSettingsDTO]
}

// MARK: - Backup Manager
@MainActor
final class BackupManager {
    static let shared = BackupManager()
    
    // Backup Document UTType
    static let backupUTType = UTType(exportedAs: "com.bifi.backup")
    
    private init() {}
    
    // MARK: - Export
    func createBackup(modelContext: ModelContext) throws -> URL {
        // Fetch all data
        let transactions = try modelContext.fetch(FetchDescriptor<Transaction>())
        let categories = try modelContext.fetch(FetchDescriptor<Category>())
        let groups = try modelContext.fetch(FetchDescriptor<CategoryGroup>())
        let budgetMonths = try modelContext.fetch(FetchDescriptor<BudgetMonth>())
        let categoryBudgets = try modelContext.fetch(FetchDescriptor<CategoryBudget>())
        let settings = try modelContext.fetch(FetchDescriptor<AppSettings>())
        
        // Convert to DTOs
        let backupData = BackupData(
            version: 1,
            timestamp: Date(),
            transactions: transactions.map {
                TransactionDTO(id: $0.id, date: $0.date, note: $0.note, categoryId: $0.categoryId, type: $0.type, currency: $0.currency, amount: $0.amount, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            categories: categories.map {
                CategoryDTO(id: $0.id, name: $0.name, icon: $0.icon, colorHex: $0.colorHex, isDefault: $0.isDefault, sortOrder: $0.sortOrder, groupId: $0.group?.id, isExpenseEnabled: $0.isExpenseEnabled, isIncomeEnabled: $0.isIncomeEnabled, isSavingsEnabled: $0.isSavingsEnabled)
            },
            groups: groups.map {
                CategoryGroupDTO(id: $0.id, name: $0.name, sortOrder: $0.sortOrder, isSystem: $0.isSystem)
            },
            budgetMonths: budgetMonths.map {
                BudgetMonthDTO(id: $0.id, monthKey: $0.monthKey, primaryMonthlyBudget: $0.primaryMonthlyBudget, secondaryMonthlyBudget: $0.secondaryMonthlyBudget, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            categoryBudgets: categoryBudgets.map {
                CategoryBudgetDTO(id: $0.id, categoryId: $0.categoryId, monthKey: $0.monthKey, primaryLimit: $0.primaryLimit, secondaryLimit: $0.secondaryLimit, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            settings: settings.map {
                AppSettingsDTO(id: $0.id, primaryCurrencyCode: $0.primaryCurrencyCode, secondaryCurrencyCode: $0.secondaryCurrencyCode, appearance: $0.appearance, hapticsEnabled: $0.hapticsEnabled, appLockEnabled: $0.appLockEnabled, dashboardWidgetOrder: $0.dashboardWidgetOrder, financialMonthStartDay: $0.financialMonthStartDay, updatedAt: $0.updatedAt)
            }
        )
        
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backupData)
        
        // Save to temporary file
        let fileName = "BiFi_Backup_\(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).json"
        
        // Use temporary directory but try to persist file if possible? No, tmp is fine for sharing.
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL)
        
        return tempURL
    }
    
    // MARK: - Import
    func restoreBackup(from url: URL, modelContext: ModelContext) throws {
        // Start accessing security scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            throw BackupError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        // Decode JSON
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // 1. Validate Data Integrity BEFORE deleting anything
        let backupData: BackupData
        do {
            backupData = try decoder.decode(BackupData.self, from: data)
        } catch {
            throw BackupError.decodingFailed(error)
        }
        
        // Check version compatibility (future proofing)
        guard backupData.version <= 1 else {
            throw BackupError.versionIncompatible
        }
        
        // 2. Perform restoration
        // Clear existing data (Caution: Destructive!)
        try modelContext.delete(model: Transaction.self)
        try modelContext.delete(model: Category.self)
        try modelContext.delete(model: CategoryGroup.self)
        try modelContext.delete(model: BudgetMonth.self)
        try modelContext.delete(model: CategoryBudget.self)
        try modelContext.delete(model: AppSettings.self)
        
        // Restore Groups
        var groupMap: [UUID: CategoryGroup] = [:]
        for dto in backupData.groups {
            let group = CategoryGroup(id: dto.id, name: dto.name, sortOrder: dto.sortOrder, isSystem: dto.isSystem)
            modelContext.insert(group)
            groupMap[dto.id] = group
        }
        
        // Restore Categories
        for dto in backupData.categories {
            let category = Category(
                id: dto.id,
                name: dto.name,
                icon: dto.icon,
                colorHex: dto.colorHex,
                isDefault: dto.isDefault,
                isExpenseEnabled: dto.isExpenseEnabled ?? true,
                isIncomeEnabled: dto.isIncomeEnabled ?? false,
                isSavingsEnabled: dto.isSavingsEnabled ?? false,
                sortOrder: dto.sortOrder,
                group: dto.groupId.flatMap { groupMap[$0] }
            )
            modelContext.insert(category)
        }
        
        // Restore Transactions
        for dto in backupData.transactions {
            let transaction = Transaction(
                id: dto.id,
                date: dto.date,
                note: dto.note,
                categoryId: dto.categoryId,
                type: dto.type,
                currency: dto.currency,
                amount: dto.amount,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt
            )
            modelContext.insert(transaction)
        }
        
        // Restore Budget Months
        for dto in backupData.budgetMonths {
            let budget = BudgetMonth(
                id: dto.id,
                monthKey: dto.monthKey,
                primaryMonthlyBudget: dto.primaryMonthlyBudget,
                secondaryMonthlyBudget: dto.secondaryMonthlyBudget,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt
            )
            modelContext.insert(budget)
        }
        
        // Restore Category Budgets
        for dto in backupData.categoryBudgets {
            let budget = CategoryBudget(
                id: dto.id,
                categoryId: dto.categoryId,
                monthKey: dto.monthKey,
                primaryLimit: dto.primaryLimit,
                secondaryLimit: dto.secondaryLimit,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt
            )
            modelContext.insert(budget)
        }
        
        // Restore Settings
        for dto in backupData.settings {
            let settings = AppSettings(
                id: dto.id,
                primaryCurrencyCode: dto.primaryCurrencyCode,
                secondaryCurrencyCode: dto.secondaryCurrencyCode,
                appearance: dto.appearance,
                hapticsEnabled: dto.hapticsEnabled,
                appLockEnabled: dto.appLockEnabled,
                dashboardWidgetOrder: dto.dashboardWidgetOrder,
                financialMonthStartDay: dto.financialMonthStartDay ?? 1,
                updatedAt: dto.updatedAt
            )
            modelContext.insert(settings)
        }
        
        try modelContext.save()
        HapticsHelper.shared.notification(.success)
    }
}

enum BackupError: LocalizedError {
    case accessDenied
    case decodingFailed(Error)
    case versionIncompatible
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Could not access the backup file."
        case .decodingFailed(let error):
            return "Failed to read backup file: \(error.localizedDescription)"
        case .versionIncompatible:
            return "This backup file is from a newer version of the app and cannot be restored."
        }
    }
}

// MARK: - Helper Extension for Batch Delete
extension ModelContext {
    func delete<T: PersistentModel>(model: T.Type) throws {
        try delete(model: T.self, where: #Predicate { _ in true })
    }
}
