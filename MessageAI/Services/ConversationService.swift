import Foundation
import FirebaseFirestore
import SwiftData

@MainActor
class ConversationService {
    static let shared = ConversationService()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    func findOrCreateConversation(currentUserID: String, otherUserID: String, modelContext: ModelContext) async throws -> Conversation {
        let conversations = try await db.collection("conversations")
            .whereField("participantIDs", arrayContains: currentUserID)
            .getDocuments()
        
        for document in conversations.documents {
            let data = document.data()
            if let participantIDs = data["participantIDs"] as? [String],
               participantIDs.contains(otherUserID),
               participantIDs.count == 2 {
                if let conversation = Conversation.fromDictionary(data) {
                    modelContext.insert(conversation)
                    return conversation
                }
            }
        }
        
        let conversationID = UUID().uuidString
        let conversation = Conversation(
            id: conversationID,
            isGroup: false,
            participantIDs: [currentUserID, otherUserID],
            lastMessageTime: Date()
        )
        
        try await db.collection("conversations").document(conversationID).setData(conversation.toDictionary())
        modelContext.insert(conversation)
        
        return conversation
    }
    
    func fetchConversations(userID: String, modelContext: ModelContext) async throws -> [Conversation] {
        let snapshot = try await db.collection("conversations")
            .whereField("participantIDs", arrayContains: userID)
            .order(by: "lastMessageTime", descending: true)
            .getDocuments()
        
        var conversations: [Conversation] = []
        
        for document in snapshot.documents {
            if let conversation = Conversation.fromDictionary(document.data()) {
                modelContext.insert(conversation)
                conversations.append(conversation)
            }
        }
        
        return conversations
    }
    
    func updateLastMessage(conversationID: String, message: String) async throws {
        try await db.collection("conversations").document(conversationID).updateData([
            "lastMessage": message,
            "lastMessageTime": Date()
        ])
    }
}
