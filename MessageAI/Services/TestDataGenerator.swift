//
//  TestDataGenerator.swift
//  MessageAI
//
//  Generates test conversation data for AI feature testing
//

import Foundation
import FirebaseFirestore

@MainActor
class TestDataGenerator {
    static let shared = TestDataGenerator()
    
    private init() {}
    
    // MARK: - Generate Test Conversation
    
    func generateTestConversation(currentUserID: String) async throws -> String {
        print("🧪 TestDataGenerator: Creating test conversation...")
        
        let db = Firestore.firestore()
        let testUserID = "test-user-\(UUID().uuidString.prefix(8))"
        let conversationID = "test-conv-\(UUID().uuidString)"
        
        // Create test conversation
        let conversationData: [String: Any] = [
            "id": conversationID,
            "participantIDs": [currentUserID, testUserID],
            "isGroup": false,
            "createdAt": Timestamp(date: Date().addingTimeInterval(-86400)), // 1 day ago
            "lastMessage": "Let's finalize the project plan",
            "lastMessageTime": Timestamp(date: Date()),
            "lastSenderID": testUserID
        ]
        
        try await db.collection("conversations")
            .document(conversationID)
            .setData(conversationData)
        
        print("✅ Created test conversation: \(conversationID)")
        
        // Generate test messages
        let messages = generateTestMessages(conversationID: conversationID, currentUserID: currentUserID, testUserID: testUserID)
        
        // Add messages to Firestore
        for (index, message) in messages.enumerated() {
            let messageID = "msg-\(index)-\(UUID().uuidString.prefix(8))"
            var messageData = message
            messageData["id"] = messageID
            
            try await db.collection("conversations")
                .document(conversationID)
                .collection("messages")
                .document(messageID)
                .setData(messageData)
            
            // Add delay to avoid rate limiting
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        print("✅ Created \(messages.count) test messages")
        
        return conversationID
    }
    
    // MARK: - Generate Test Messages
    
    private func generateTestMessages(conversationID: String, currentUserID: String, testUserID: String) -> [[String: Any]] {
        let baseTime = Date().addingTimeInterval(-86400) // Start 1 day ago
        
        let messageTemplates: [(sender: String, content: String, offset: TimeInterval)] = [
            // Introduction
            (testUserID, "Hey! Ready to discuss the new project?", 0),
            (currentUserID, "Absolutely! What's the timeline looking like?", 60),
            
            // Decision making
            (testUserID, "We need to decide on the tech stack. I'm thinking Firebase for the backend.", 300),
            (currentUserID, "That sounds good. Let's go with Firebase for backend infrastructure.", 360),
            (testUserID, "Perfect! Decision made. I'll set that up.", 420),
            
            // Action items
            (currentUserID, "Sarah, can you send the design mockups by Friday?", 900),
            (testUserID, "Sure! I'll have them ready by end of week.", 960),
            (currentUserID, "Also, Mike needs to review the database schema by tomorrow.", 1020),
            
            // Urgent items
            (testUserID, "URGENT: The API key expired! We need to generate a new one ASAP.", 1500),
            (currentUserID, "On it! I'll regenerate it right now.", 1560),
            
            // More decisions
            (testUserID, "Should we launch on March 15th or March 22nd?", 2400),
            (currentUserID, "Let's go with March 15th. That gives us more buffer time.", 2460),
            (testUserID, "Agreed. Launch date: March 15th confirmed.", 2520),
            
            // Regular discussion
            (currentUserID, "How's the progress on the authentication system?", 3600),
            (testUserID, "Going well! OAuth integration is complete.", 3660),
            
            // More action items
            (testUserID, "Can someone test the payment integration before the demo?", 4500),
            (currentUserID, "I can handle that. I'll test it by Wednesday.", 4560),
            
            // Pricing decision
            (testUserID, "We need to finalize pricing. Thinking $99/month for pro tier?", 5400),
            (currentUserID, "That seems reasonable. Let's tentatively set it at $99/month.", 5460),
            
            // Blocker
            (currentUserID, "Blocker: Still waiting on legal approval for the terms of service.", 6300),
            (testUserID, "I'll follow up with the legal team today.", 6360),
            
            // Assignment
            (testUserID, "Emily, please prepare the marketing materials by next Monday.", 7200),
            (currentUserID, "Got it. Marketing materials due Monday.", 7260),
            
            // Final messages
            (testUserID, "Great progress today! Let's sync again tomorrow at 2pm.", 8000),
            (currentUserID, "Perfect. See you tomorrow!", 8060),
            (testUserID, "Don't forget to update the project board.", 8100),
            (currentUserID, "Will do! Thanks for the reminder.", 8160)
        ]
        
        return messageTemplates.map { template in
            let timestamp = baseTime.addingTimeInterval(template.offset)
            return [
                "conversationID": conversationID,
                "senderID": template.sender,
                "content": template.content,
                "timestamp": Timestamp(date: timestamp),
                "status": "read",
                "type": "text",
                "readBy": [currentUserID, testUserID],
                "reactions": [:] as [String: Any],
                "deletedFor": [] as [String],
                "deletedForEveryone": false
            ]
        }
    }
    
    // MARK: - Delete Test Conversation
    
    func deleteTestConversation(_ conversationID: String) async throws {
        print("🧹 TestDataGenerator: Deleting test conversation...")
        
        let db = Firestore.firestore()
        
        // Delete all messages
        let messagesSnapshot = try await db.collection("conversations")
            .document(conversationID)
            .collection("messages")
            .getDocuments()
        
        for document in messagesSnapshot.documents {
            try await document.reference.delete()
        }
        
        // Delete conversation
        try await db.collection("conversations")
            .document(conversationID)
            .delete()
        
        print("✅ Deleted test conversation: \(conversationID)")
    }
}

