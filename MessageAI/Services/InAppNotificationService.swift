import Foundation
import FirebaseFirestore
import UserNotifications
import Combine

@MainActor
class InAppNotificationService: ObservableObject {
    static let shared = InAppNotificationService()
    
    @Published var showNotification = false
    @Published var notificationMessage = ""
    @Published var notificationTitle = ""
    @Published var conversationID: String?
    
    var activeConversationID: String?
    
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()
    private var lastNotificationID: String?
    
    private init() {}
    
    func startListening(userID: String) {
        listener = db.collection("conversations")
            .whereField("participantIDs", arrayContains: userID)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else {
                    return
                }
                
                for change in snapshot.documentChanges {
                    if change.type == .modified {
                        Task {
                            await self.handleConversationUpdate(change.document, userID: userID)
                        }
                    }
                }
            }
    }
    
    private func handleConversationUpdate(_ document: QueryDocumentSnapshot, userID: String) async {
        let data = document.data()
        
        guard let lastSenderID = data["lastSenderID"] as? String,
              lastSenderID != userID,
              let lastMessage = data["lastMessage"] as? String,
              let conversationID = data["id"] as? String,
              let lastMessageTime = data["lastMessageTime"] as? Timestamp else {
            return
        }
        
        // Don't show notification if user is viewing this conversation
        guard conversationID != activeConversationID else {
            return
        }
        
        // Create unique notification ID
        let notificationID = "\(conversationID)-\(lastMessageTime.seconds)"
        
        // Don't show if this is the same notification we just showed
        guard notificationID != lastNotificationID else {
            return
        }
        
        // Don't show notification for group creation message if user is the creator
        if let creatorID = data["creatorID"] as? String,
           creatorID == userID,
           lastMessage.contains("created") {
            return
        }
        
        // Fetch sender info
        guard let sender = try? await AuthService.shared.fetchUserDocument(userId: lastSenderID) else {
            return
        }
        
        let isGroup = data["isGroup"] as? Bool ?? false
        let groupName = data["name"] as? String
        
        await MainActor.run {
            if isGroup {
                self.notificationTitle = groupName ?? "Group Chat"
                self.notificationMessage = "\(sender.displayName): \(lastMessage)"
            } else {
                self.notificationTitle = sender.displayName
                self.notificationMessage = lastMessage
            }
            
            self.conversationID = conversationID
            self.lastNotificationID = notificationID
            self.showNotification = true
            
            // Auto-hide after 4 seconds
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await MainActor.run {
                    self.showNotification = false
                }
            }
        }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        lastNotificationID = nil
    }
}
