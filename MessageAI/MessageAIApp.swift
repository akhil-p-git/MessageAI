import SwiftUI
import SwiftData
import FirebaseCore

@main
struct MessageAIApp: App {
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [User.self, Conversation.self, Message.self])
    }
}
