import Foundation
import FirebaseFirestore
import SwiftData

@MainActor
class GroupChatService {
    static let shared = GroupChatService()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    func createGroupChat(name: String, participantIDs: [String], creatorID: String, modelContext: ModelContext) async throws -> Conversation {
        let conversationID = UUID().uuidString
        
        // Get creator name
        let creatorUser = try await AuthService.shared.fetchUserDocument(userId: creatorID)
        
        let conversation = Conversation(
            id: conversationID,
            isGroup: true,
            participantIDs: participantIDs,
            name: name,
            lastMessage: "\(creatorUser.displayName) created the group",
            lastMessageTime: Date(),
            creatorID: creatorID
        )
        
        var firestoreData = conversation.toDictionary()
        firestoreData["lastMessageTime"] = Timestamp(date: Date())
        firestoreData["lastSenderID"] = creatorID
        firestoreData["creatorID"] = creatorID
        firestoreData["typingUsers"] = [String]()
        
        try await db.collection("conversations").document(conversationID).setData(firestoreData)
        modelContext.insert(conversation)
        try? modelContext.save()
        
        // Send system message with better formatting
        let systemMessage = Message(
            id: UUID().uuidString,
            conversationID: conversationID,
            senderID: creatorID,
            content: "\(creatorUser.displayName) created \"\(name)\"",
            timestamp: Date(),
            status: .sent,
            type: .text
        )
        
        var messageData = systemMessage.toDictionary()
        messageData["timestamp"] = Timestamp(date: Date())
        
        try await db.collection("conversations")
            .document(conversationID)
            .collection("messages")
            .document(systemMessage.id)
            .setData(messageData)
        
        return conversation
    }
    
    func addParticipant(conversationID: String, userID: String) async throws {
        try await db.collection("conversations").document(conversationID).updateData([
            "participantIDs": FieldValue.arrayUnion([userID])
        ])
    }
    
    func removeParticipant(conversationID: String, userID: String) async throws {
        try await db.collection("conversations").document(conversationID).updateData([
            "participantIDs": FieldValue.arrayRemove([userID])
        ])
    }
}
