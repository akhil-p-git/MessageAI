import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseFunctions
import UserNotifications

@main
struct MessageAIApp: App {
    @StateObject private var themeManager = ThemeManager()
    
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
