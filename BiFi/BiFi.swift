import SwiftUI
import SwiftData

// MARK: - Main App Entry Point
@main
struct BiFi: App {
    @State private var authManager = AuthenticationManager()
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsQuery: [AppSettings]
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Transaction.self,
            Category.self,
            BudgetMonth.self,
            CategoryBudget.self,
            CategoryGroup.self,
            AppSettings.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            AppRootView(authManager: authManager)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(from: oldPhase, to: newPhase)
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        // Lock when going to background if app lock is enabled
        if newPhase == .background {
            // Check if app lock is enabled in settings
            let context = sharedModelContainer.mainContext
            let descriptor = FetchDescriptor<AppSettings>()
            if let settings = try? context.fetch(descriptor).first,
               settings.appLockEnabled {
                authManager.lock()
            }
        }
    }
}

// MARK: - App Root View
struct AppRootView: View {
    @Bindable var authManager: AuthenticationManager
    @Query private var settings: [AppSettings]
    
    private var currentSettings: AppSettings? {
        settings.first
    }
    
    private var appLockEnabled: Bool {
        currentSettings?.appLockEnabled ?? false
    }
    
    private var appearanceMode: AppearanceMode {
        currentSettings?.appearance ?? .system
    }
    
    var body: some View {
        Group {
            if appLockEnabled && !authManager.isUnlocked {
                LockView(authManager: authManager)
            } else {
                ContentView()
            }
        }
        .environment(authManager)
        .preferredColorScheme(colorScheme)
        .onChange(of: currentSettings?.hapticsEnabled) { _, newValue in
            HapticsHelper.shared.updateEnabled(newValue ?? true)
        }
    }
    
    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
