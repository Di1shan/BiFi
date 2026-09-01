import SwiftUI

// MARK: - Main Content View with Tab Navigation
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedTab: TabItem = .dashboard
    
    var body: some View {
        ZStack {
            // Main Content Area
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView()
                case .transactions:
                    TransactionsView()
                case .budgets:
                    BudgetsView()
                case .settings:
                    SettingsView()
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
        .safeAreaInset(edge: .bottom) {
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            // Configure tab bar appearance removed as we use custom one
            DataSeeder.seedIfNeeded(modelContext: modelContext)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selectedTab)
    }
}


#Preview {
    ContentView()
        .modelContainer(for: [Transaction.self, Category.self, BudgetMonth.self, CategoryBudget.self, CategoryGroup.self, AppSettings.self], inMemory: true)
}
