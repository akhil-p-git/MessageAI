import UserNotifications
import FirebaseMessaging
import FirebaseFirestore
import FirebaseAuth
import UIKit
import Combine

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var currentChatID: String? = nil  // Track which chat is open
    
    private override init() {
        super.init()
    }
    
    // MARK: - Setup
    
    func setup() async {
        print("\n🔔 Setting up notifications...")
        
        // Request permission
        await requestAuthorization()
        
        // Register for remote notifications
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
        
        // Set FCM delegate
        Messaging.messaging().delegate = self
        
        print("✅ Notification setup complete\n")
    }
    
    private func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted {
                print("✅ Notification permission granted")
            } else {
                print("⚠️ Notification permission denied")
            }
        } catch {
            print("❌ Error requesting notification permission: \(error)")
        }
    }
    
    // MARK: - Show Local Notification
    
    func showNotification(
        title: String,
        body: String,
        conversationID: String,
        senderID: String,
        currentUserID: String
    ) {
        // Rule 1: Don't show if you sent it
        guard senderID != currentUserID else {
            print("🚫 Not showing notification: you sent this message")
            return
        }
        
        // Rule 2: Don't show if you're in this chat
        guard conversationID != currentChatID else {
            print("🚫 Not showing notification: you're in this chat")
            return
        }
        
        print("🔔 Showing notification: \(title) - \(body)")
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [
            "conversationID": conversationID,
            "senderID": senderID
        ]
        
        // Show immediately
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error showing notification: \(error)")
            } else {
                print("✅ Notification shown")
            }
        }
    }
    
    // MARK: - Chat Tracking
    
    func enterChat(_ conversationID: String) {
        currentChatID = conversationID
        print("📍 Entered chat: \(conversationID.prefix(8))...")
    }
    
    func exitChat() {
        currentChatID = nil
        print("📍 Exited chat")
    }
    
    // MARK: - FCM Token Management
    
    func saveDeviceToken(userId: String, token: String) async {
        let db = Firestore.firestore()
        
        do {
            try await db.collection("users")
                .document(userId)
                .updateData([
                    "fcmToken": token,
                    "fcmTokenUpdated": Timestamp(date: Date())
                ])
            
            print("✅ FCM token saved: \(token.prefix(20))...")
        } catch {
            print("❌ Error saving FCM token: \(error)")
        }
    }
}

// MARK: - FCM Delegate

extension NotificationManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        
        print("📱 FCM Token received: \(token.prefix(20))...")
        
        // Save token to Firestore
        Task { @MainActor in
            if let userId = Auth.auth().currentUser?.uid {
                await saveDeviceToken(userId: userId, token: token)
            }
        }
    }
}

// MARK: - Notification Delegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    // Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        if let conversationID = userInfo["conversationID"] as? String {
            print("🔔 User tapped notification for conversation: \(conversationID.prefix(8))...")
            // TODO: Navigate to conversation
        }
        
        completionHandler()
    }
    
    // Handle notification while app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner even when app is open
        completionHandler([.banner, .sound])
    }
}

