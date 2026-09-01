import SwiftUI
import SwiftData

// MARK: - Category Manager View
struct CategoryManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \CategoryGroup.sortOrder) private var groups: [CategoryGroup]
    
    @State private var showAddCategory = false
    @State private var categoryToEdit: Category?
    @State private var categoryToDelete: Category?
    @State private var showDeleteConfirmation = false
    @State private var showGroupManager = false
    
    var body: some View {
        List {
            // Grouped Categories
            ForEach(groups) { group in
                Section {
                    let groupCategories = categories.filter { $0.group?.id == group.id }
                    ForEach(groupCategories) { category in
                        CategoryRowView(category: category)
                            .contentShape(Rectangle())
                            .onTapGesture { categoryToEdit = category }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    categoryToDelete = category
                                    showDeleteConfirmation = true
                                } label: { Label("Delete", systemImage: "trash") }
                                
                                Button {
                                    categoryToEdit = category
                                } label: { Label("Edit", systemImage: "pencil") }
                                .tint(.blue)
                            }
                    }
                } header: {
                    Text(group.name)
                }
            }
            
            // Uncategorized
            let uncategorized = categories.filter { $0.group == nil }
            if !uncategorized.isEmpty {
                Section("Uncategorized") {
                    ForEach(uncategorized) { category in
                        CategoryRowView(category: category)
                            .contentShape(Rectangle())
                            .onTapGesture { categoryToEdit = category }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    categoryToDelete = category
                                    showDeleteConfirmation = true
                                } label: { Label("Delete", systemImage: "trash") }
                                
                                Button {
                                    categoryToEdit = category
                                } label: { Label("Edit", systemImage: "pencil") }
                                .tint(.blue)
                            }
                    }
                }
            }
            
            // Bottom Padding for Tab Bar
            Section {
                Color.clear
                    .frame(height: 60)
                    .listRowBackground(Color.clear)
            }
            .listSectionSeparator(.hidden)
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Groups") {
                    showGroupManager = true
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddCategory = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showGroupManager) {
            GroupManagerView()
        }
        .sheet(isPresented: $showAddCategory) {
            AddEditCategoryView()
        }
        .sheet(item: $categoryToEdit) { category in
            AddEditCategoryView(category: category)
        }
        .alert("Delete Category?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { categoryToDelete = nil }
            Button("Delete", role: .destructive) {
                if let category = categoryToDelete { deleteCategory(category) }
            }
        } message: {
            Text("Transactions with this category will become uncategorized.")
        }
    }
    
    private func deleteCategory(_ category: Category) {
        let descriptor = FetchDescriptor<Transaction>()
        if let transactions = try? modelContext.fetch(descriptor) {
            for transaction in transactions where transaction.categoryId == category.id {
                transaction.categoryId = nil
            }
        }
        modelContext.delete(category)
        try? modelContext.save()
        HapticsHelper.shared.notification(.warning)
        categoryToDelete = nil
    }
}

// MARK: - Category Row View
struct CategoryRowView: View {
    let category: Category
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: category.colorHex).opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundColor(Color(hex: category.colorHex))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                if category.isDefault {
                    Text("Default")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Group Manager View
struct GroupManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CategoryGroup.sortOrder) private var groups: [CategoryGroup]
    
    @State private var newGroupName = ""
    @State private var groupToEdit: CategoryGroup?
    @State private var editingName = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section("Add New Group") {
                    HStack {
                        TextField("Group Name", text: $newGroupName)
                            .submitLabel(.done)
                            .onSubmit(addGroup)
                        
                        Button(action: addGroup) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                
                Section("Reorder & Edit") {
                    ForEach(groups) { group in
                        if groupToEdit?.id == group.id {
                            HStack {
                                TextField("Group Name", text: $editingName)
                                    .submitLabel(.done)
                                    .onSubmit { updateGroup(group) }
                                
                                Button("Done") { updateGroup(group) }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                            }
                        } else {
                            HStack {
                                Text(group.name)
                                    .fontWeight(.medium)
                                Spacer()
                                Button {
                                    groupToEdit = group
                                    editingName = group.name
                                } label: {
                                    Image(systemName: "pencil")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onMove(perform: moveGroups)
                    .onDelete(perform: deleteGroup)
                }
            }
            .navigationTitle("Manage Groups")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
        }
    }
    
    private func addGroup() {
        let trimmedName = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        let maxSort = groups.map(\.sortOrder).max() ?? -1
        let newGroup = CategoryGroup(name: trimmedName, sortOrder: maxSort + 1)
        modelContext.insert(newGroup)
        try? modelContext.save()
        newGroupName = ""
    }
    
    private func updateGroup(_ group: CategoryGroup) {
        let trimmedName = editingName.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty {
            group.name = trimmedName
            try? modelContext.save()
        }
        groupToEdit = nil
    }
    
    private func moveGroups(from source: IndexSet, to destination: Int) {
        var sortedGroups = groups
        sortedGroups.move(fromOffsets: source, toOffset: destination)
        for (index, group) in sortedGroups.enumerated() {
            group.sortOrder = index
        }
        try? modelContext.save()
    }
    
    private func deleteGroup(at offsets: IndexSet) {
        for index in offsets {
            let group = groups[index]
            // Removing a group sets categories.group to nil (Rule: .nullify)
            modelContext.delete(group)
        }
        try? modelContext.save()
    }
}

// MARK: - Add/Edit Category View
struct AddEditCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    @Query(sort: \CategoryGroup.sortOrder) private var groups: [CategoryGroup]
    
    private var existingCategory: Category?
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "tag.fill"
    @State private var selectedColorHex: String = "#FF6B6B"
    @State private var selectedGroupId: UUID?
    @State private var selectedUsage: CategoryUsageType = .expense
    
    private var isEditing: Bool { existingCategory != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    
    private enum CategoryUsageType: String, CaseIterable, Identifiable {
        case expense = "Expense"
        case income = "Income"
        case savings = "Savings"
        
        var id: String { rawValue }
    }
    
    // Common SF Symbols - Expanded set for various expense categories
    private let availableIcons = [
        // Food & Dining
        "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill", "wineglass.fill",
        // Transportation
        "car.fill", "bus.fill", "tram.fill", "bicycle", "fuelpump.fill", "airplane",
        // Home & Utilities  
        "house.fill", "lightbulb.fill", "bolt.fill", "drop.fill", "flame.fill", "wifi",
        // Shopping
        "bag.fill", "cart.fill", "creditcard.fill", "basket.fill", "giftcard.fill",
        // Health & Fitness
        "heart.fill", "dumbbell.fill", "figure.run", "cross.case.fill", "pills.fill",
        // Entertainment
        "gamecontroller.fill", "tv.fill", "music.note", "film.fill", "ticket.fill", "book.fill",
        // Finance & Business
        "banknote.fill", "dollarsign.circle.fill", "chart.line.uptrend.xyaxis", "briefcase.fill",
        // Communication
        "phone.fill", "envelope.fill", "bubble.left.fill", "video.fill",
        // Education
        "graduationcap.fill", "pencil", "book.closed.fill", "backpack.fill",
        // Personal Care
        "scissors", "comb.fill", "mouth.fill", "eyeglasses",
        // Travel
        "suitcase.fill", "map.fill", "bed.double.fill", "beach.umbrella.fill",
        // Pets
        "pawprint.fill", "hare.fill", "fish.fill",
        // Nature & Weather
        "leaf.fill", "sun.max.fill", "moon.fill", "snowflake", "cloud.rain.fill",
        // General
        "star.fill", "tag.fill", "folder.fill", "doc.text.fill", "paperclip",
        "gift.fill", "wrench.fill", "hammer.fill", "paintbrush.fill", "camera.fill",
        "music.mic", "ellipsis.circle.fill"
    ]
    
    init(category: Category? = nil) {
        self.existingCategory = category
        if let category = category {
            _name = State(initialValue: category.name)
            _selectedIcon = State(initialValue: category.icon)
            _selectedColorHex = State(initialValue: category.colorHex)
            _selectedGroupId = State(initialValue: category.group?.id)
            
            // Determine initial usage type
            if category.isSavingsEnabled {
                _selectedUsage = State(initialValue: .savings)
            } else if category.isIncomeEnabled {
                _selectedUsage = State(initialValue: .income)
            } else {
                // Default to expense if strictly expense or both (legacy)
                _selectedUsage = State(initialValue: .expense)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Category name", text: $name)
                    
                    if !groups.isEmpty {
                        Picker("Group", selection: $selectedGroupId) {
                            Text("None").tag(nil as UUID?)
                            ForEach(groups) { group in
                                Text(group.name).tag(group.id as UUID?)
                            }
                        }
                    }
                }
                
                Section(header: Text("Category Type")) {
                    Picker("Type", selection: $selectedUsage) {
                        ForEach(CategoryUsageType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("Icon")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                        ForEach(availableIcons, id: \.self) { icon in
                            iconButton(for: icon)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Color")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                        ForEach(Color.categoryColorHexes, id: \.self) { hex in
                            colorButton(for: hex)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Preview")) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                            .fill(Color(hex: selectedColorHex).opacity(0.15))
                            .frame(width: 44, height: 44)
                            
                            Image(systemName: selectedIcon)
                                .font(.title3)
                                .foregroundColor(Color(hex: selectedColorHex))
                        }
                        
                        VStack(alignment: .leading) {
                            Text(name.isEmpty ? "Category Name" : name)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(name.isEmpty ? .secondary : .primary)
                            
                            if let id = selectedGroupId, let group = groups.first(where: { $0.id == id }) {
                                Text(group.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(isEditing ? "Edit Category" : "Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCategory() }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private func iconButton(for icon: String) -> some View {
        let isSelected = selectedIcon == icon
        return Button {
            HapticsHelper.shared.selection()
            selectedIcon = icon
        } label: {
            ZStack {
                Circle()
                    .fill(isSelected ? Color(hex: selectedColorHex) : Color(.systemGray5))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(isSelected ? .white : .primary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func colorButton(for hex: String) -> some View {
        let isSelected = selectedColorHex == hex
        return Button {
            HapticsHelper.shared.selection()
            selectedColorHex = hex
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 44, height: 44)
                if isSelected {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 3)
                        .frame(width: 44, height: 44)
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func saveCategory() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        HapticsHelper.shared.notification(.success)
        
        // Find group
        let selectedGroup: CategoryGroup? = {
            if let id = selectedGroupId {
                return groups.first { $0.id == id }
            }
            return nil
        }()
        
        // Determine flags based on usage
        let isExpense = selectedUsage == .expense
        let isIncome = selectedUsage == .income
        let isSavings = selectedUsage == .savings
        
        if let existing = existingCategory {
            existing.name = trimmedName
            existing.icon = selectedIcon
            existing.colorHex = selectedColorHex
            existing.group = selectedGroup
            existing.isExpenseEnabled = isExpense
            existing.isIncomeEnabled = isIncome
            existing.isSavingsEnabled = isSavings
        } else {
            let maxSortOrder = allCategories.map(\.sortOrder).max() ?? -1
            let category = Category(
                name: trimmedName,
                icon: selectedIcon,
                colorHex: selectedColorHex,
                isDefault: false,
                isExpenseEnabled: isExpense,
                isIncomeEnabled: isIncome,
                isSavingsEnabled: isSavings,
                sortOrder: maxSortOrder + 1,
                group: selectedGroup
            )
            modelContext.insert(category)
        }
        
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        CategoryManagerView()
    }
    .modelContainer(for: [Transaction.self, Category.self, BudgetMonth.self, CategoryBudget.self, CategoryGroup.self, AppSettings.self], inMemory: true)
}
