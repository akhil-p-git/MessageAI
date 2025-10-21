import Foundation
import FirebaseFirestore
import SwiftUI
import Combine

@MainActor
class InAppNotificationService: ObservableObject {
    static let shared = InAppNotificationService()
    
    @Published var notifications: [NotificationItem] = []
    private var listener: ListenerRegistration?
    private var lastProcessedTime = Date()
    
    private init() {}
    
    func startListening(userID: String) {
        let db = Firestore.firestore()
        
        // Listen to all conversations where user is a participant
        listener = db.collection("conversations")
            .whereField("participantIDs", arrayContains: userID)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let snapshot = snapshot else {
                    print("Error listening to conversations: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                
                for change in snapshot.documentChanges {
                    if change.type == .modified {
                        let data = change.document.data()
                        
                        // Check if last message time is recent (within last 5 seconds)
                        if let lastMessageTime = data["lastMessageTime"] as? Date,
                           lastMessageTime > self.lastProcessedTime,
                           let lastMessage = data["lastMessage"] as? String,
                           let conversationID = data["id"] as? String {
                            
                            let conversationName: String
                            if let isGroup = data["isGroup"] as? Bool, isGroup {
                                conversationName = data["name"] as? String ?? "Group Chat"
                            } else {
                                conversationName = "New Message"
                            }
                            
                            self.showNotification(
                                conversationID: conversationID,
                                title: conversationName,
                                message: lastMessage
                            )
                            
                            self.lastProcessedTime = Date()
                        }
                    }
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
    }
    
    private func showNotification(conversationID: String, title: String, message: String) {
        let notification = NotificationItem(
            id: UUID().uuidString,
            conversationID: conversationID,
            title: title,
            message: message,
            timestamp: Date()
        )
        
        notifications.append(notification)
        
        // Auto-dismiss after 4 seconds
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run {
                self.notifications.removeAll { $0.id == notification.id }
            }
        }
    }
    
    func dismissNotification(id: String) {
        notifications.removeAll { $0.id == id }
    }
}

struct NotificationItem: Identifiable {
    let id: String
    let conversationID: String
    let title: String
    let message: String
    let timestamp: Date
}
