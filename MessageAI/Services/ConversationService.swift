import Foundation
import FirebaseFirestore
import SwiftData

@MainActor
class ConversationService {
    static let shared = ConversationService()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    func findOrCreateConversation(currentUserID: String, otherUserID: String, modelContext: ModelContext) async throws -> Conversation {
        print("\n🔍 Finding or creating conversation...")
        print("   Current User: \(currentUserID.prefix(8))...")
        print("   Other User: \(otherUserID.prefix(8))...")
        
        let conversations = try await db.collection("conversations")
            .whereField("participantIDs", arrayContains: currentUserID)
            .getDocuments()
        
        print("   Found \(conversations.documents.count) existing conversations")
        
        for document in conversations.documents {
            var data = document.data()
            
            // Convert Timestamp to Date if needed
            if let timestamp = data["lastMessageTime"] as? Timestamp {
                data["lastMessageTime"] = timestamp.dateValue()
            }
            
            if let participantIDs = data["participantIDs"] as? [String],
               participantIDs.contains(otherUserID),
               participantIDs.count == 2 {
                print("   ✅ Found existing 1-on-1 conversation: \(document.documentID)")
                
                if let conversation = Conversation.fromDictionary(data) {
                    modelContext.insert(conversation)
                    return conversation
                }
            }
        }
        
        // Create new conversation
        print("   📝 Creating new conversation...")
        
        let conversationID = UUID().uuidString
        let conversation = Conversation(
            id: conversationID,
            isGroup: false,
            participantIDs: [currentUserID, otherUserID],
            lastMessage: nil,
            lastMessageTime: Date(),
            lastSenderID: nil,
            lastMessageID: nil,
            unreadBy: [],  // No messages yet, so no unread
            creatorID: currentUserID
        )
        
        var conversationData = conversation.toDictionary()
        conversationData["lastMessageTime"] = Timestamp(date: Date())
        
        try await db.collection("conversations").document(conversationID).setData(conversationData)
        modelContext.insert(conversation)
        
        print("   ✅ Created conversation: \(conversationID)")
        
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
    
    func updateLastMessage(conversationID: String, message: String, messageID: String, senderID: String, participantIDs: [String]) async throws {
        let otherParticipants = participantIDs.filter { $0 != senderID }
        
        try await db.collection("conversations").document(conversationID).updateData([
            "lastMessage": message,
            "lastMessageTime": Timestamp(date: Date()),
            "lastSenderID": senderID,
            "lastMessageID": messageID,
            "unreadBy": otherParticipants
        ])
        
        print("   ✅ Updated conversation metadata (unreadBy: \(otherParticipants.count) users)")
    }
}
