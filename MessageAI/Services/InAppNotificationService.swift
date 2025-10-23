import Foundation
import FirebaseFirestore
import SwiftUI
import Combine

@MainActor
class InAppNotificationService: ObservableObject {
    static let shared = InAppNotificationService()
    
    @Published var notifications: [NotificationItem] = []
    @Published var activeConversationID: String?
    
    private var listener: ListenerRegistration?
    private var messageListeners: [String: ListenerRegistration] = [:]
    private var currentUserID: String?
    private var processedMessageIDs = Set<String>()
    private var lastCheckTime = Date()
    
    private init() {}
    
    func startListening(userID: String) {
        guard currentUserID == nil || currentUserID != userID else {
            print("⚠️ Already listening for user: \(userID)")
            return
        }
        
        self.currentUserID = userID
        self.lastCheckTime = Date()
        
        let db = Firestore.firestore()
        
        listener = db.collection("conversations")
            .whereField("participantIDs", arrayContains: userID)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let snapshot = snapshot else {
                    print("Error listening to conversations: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                
                for document in snapshot.documents {
                    let conversationID = document.documentID
                    
                    if self.messageListeners[conversationID] == nil {
                        self.listenToMessages(conversationID: conversationID)
                    }
                }
            }
    }
    
    private func listenToMessages(conversationID: String) {
        let db = Firestore.firestore()
        
        let listener = db.collection("conversations")
            .document(conversationID)
            .collection("messages")
            .whereField("timestamp", isGreaterThan: Timestamp(date: lastCheckTime))
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let snapshot = snapshot else {
                    return
                }
                
                for document in snapshot.documents {
                    let data = document.data()
                    let messageID = document.documentID
                    
                    guard !self.processedMessageIDs.contains(messageID) else {
                        continue
                    }
                    
                    guard let senderID = data["senderID"] as? String,
                          senderID != self.currentUserID,
                          let content = data["content"] as? String,
                          let timestamp = data["timestamp"] as? Timestamp,
                          timestamp.dateValue() > self.lastCheckTime else {
                        self.processedMessageIDs.insert(messageID)
                        continue
                    }
                    
                    self.processedMessageIDs.insert(messageID)
                    self.fetchConversationDetails(conversationID: conversationID, message: content)
                }
            }
        
        messageListeners[conversationID] = listener
    }
    
    private func fetchConversationDetails(conversationID: String, message: String) {
        let db = Firestore.firestore()
        
        db.collection("conversations").document(conversationID).getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let data = snapshot?.data() else {
                return
            }
            
            let isGroup = data["isGroup"] as? Bool ?? false
            
            let title: String
            if isGroup {
                let groupName = data["name"] as? String ?? "Group Chat"
                if let createdByName = data["createdByName"] as? String,
                   message.contains("created") {
                    // Group creation notification
                    title = "\(createdByName) added you to \"\(groupName)\""
                } else {
                    // Regular group message
                    title = groupName
                }
            } else {
                title = "New Message"
            }
            
            Task { @MainActor in
                self.showNotification(
                    conversationID: conversationID,
                    title: title,
                    message: message
                )
            }
        }
    }
    
    func stopListening() {
        listener?.remove()
        messageListeners.values.forEach { $0.remove() }
        messageListeners.removeAll()
        currentUserID = nil
    }
    
    private func showNotification(conversationID: String, title: String, message: String) {
        // Don't show notification if user is already viewing this conversation
        guard activeConversationID != conversationID else {
            print("🔕 Suppressed notification - user is viewing this conversation")
            return
        }
        
        guard !notifications.contains(where: { $0.conversationID == conversationID }) else {
            return
        }
        
        let notification = NotificationItem(
            id: UUID().uuidString,
            conversationID: conversationID,
            title: title,
            message: message,
            timestamp: Date()
        )
        
        notifications.append(notification)
        
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
