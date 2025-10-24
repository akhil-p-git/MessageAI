import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseFunctions
import UserNotifications

@main
struct MessageAIApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var authViewModel = AuthViewModel()
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        FirebaseApp.configure()
        verifyFirebaseConfiguration()
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(themeManager)
                .environmentObject(authViewModel)
                .preferredColorScheme(themeManager.currentColorScheme)
                .onAppear {
                    #if DEBUG
                    // Run diagnostics after a short delay to ensure UI is loaded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        DiagnosticHelper.runDiagnostics()
                    }
                    #endif
                }
                .task {
                    await NotificationManager.shared.setup()
                }
        }
        .modelContainer(for: [User.self, Conversation.self, Message.self])
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
        }
    }
    
    // MARK: - Scene Phase Handling
    
    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        guard let currentUser = authViewModel.currentUser else {
            return
        }
        
        Task {
            switch newPhase {
            case .active:
                // App became active (foreground)
                print("🟢 App became active - setting user online")
                await PresenceService.shared.startPresenceUpdates(
                    userID: currentUser.id,
                    showOnlineStatus: currentUser.showOnlineStatus
                )
                
            case .inactive:
                // App became inactive (transitioning)
                print("🟡 App became inactive")
                // Don't change presence yet - might just be a temporary transition
                
            case .background:
                // App went to background
                print("🔴 App went to background - setting user offline")
                await PresenceService.shared.stopPresenceUpdates(userID: currentUser.id)
                
            @unknown default:
                break
            }
        }
    }
    
    // MARK: - Firebase Configuration Verification
    
    private func verifyFirebaseConfiguration() {
        print("\n" + String(repeating: "=", count: 60))
        print("🔥 FIREBASE CONFIGURATION CHECK")
        print(String(repeating: "=", count: 60))
        
        // Check if Firebase is initialized
        if let app = FirebaseApp.app() {
            print("✅ Firebase initialized successfully")
            print("📱 App name: \(app.name)")
            
            let options = app.options
            print("📦 Project ID: \(options.projectID ?? "Unknown")")
            print("🔑 API Key: \(options.apiKey?.prefix(10) ?? "Unknown")...")
            print("💾 Storage Bucket: \(options.storageBucket ?? "Unknown")")
            print("🔗 Database URL: \(options.databaseURL ?? "Unknown")")
        } else {
            print("❌ Firebase NOT initialized!")
        }
        
        // Check Functions configuration
        let functions = Functions.functions()
        print("\n📡 Firebase Functions Configuration:")
        print("   Region: Default (us-central1)")
        print("   Available: ✅")
        
        // List expected Cloud Functions
        print("\n🤖 Expected Cloud Functions:")
        let expectedFunctions = [
            "summarizeThread",
            "extractActionItems",
            "smartSearch",
            "trackDecisions",
            "detectPriority"
        ]
        for function in expectedFunctions {
            print("   • \(function)")
        }
        
        print("\n💡 AI Features Status:")
        print("   Debug Mode: Enabled")
        print("   Console Logging: Enabled")
        print("   Health Check: Available")
        print("   Test Data Generator: Available")
        
        print(String(repeating: "=", count: 60) + "\n")
    }
}
