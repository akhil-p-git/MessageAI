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
        
        let conversation = Conversation(
            id: conversationID,
            isGroup: true,
            name: name,
            participantIDs: participantIDs,
            lastMessage: "Group created",
            lastMessageTime: Date()
        )
        
        // Save to Firestore
        try await db.collection("conversations").document(conversationID).setData(conversation.toDictionary())
        
        // Save to SwiftData
        modelContext.insert(conversation)
        
        // Send system message
        let systemMessage = Message(
            id: UUID().uuidString,
            conversationID: conversationID,
            senderID: "system",
            content: "Group chat created by \(creatorID)",
            timestamp: Date(),
            status: .sent,
            type: .text
        )
        
        try await db.collection("conversations")
            .document(conversationID)
            .collection("messages")
            .document(systemMessage.id)
            .setData(systemMessage.toDictionary())
        
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
}//
//  GroupChatServices.swift
//  MessageAI
//
//  Created by Akhil Pinnani on 10/20/25.
//

