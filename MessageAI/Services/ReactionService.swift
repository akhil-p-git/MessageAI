import Foundation
import FirebaseFirestore

@MainActor
class ReactionService {
    static let shared = ReactionService()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    func toggleReaction(messageID: String, conversationID: String, emoji: String, userID: String) async throws {
        let messageRef = db.collection("conversations")
            .document(conversationID)
            .collection("messages")
            .document(messageID)
        
        let document = try await messageRef.getDocument()
        
        guard var reactions = document.data()?["reactions"] as? [String: [String]] else {
            // No reactions yet, add first one
            try await messageRef.updateData([
                "reactions.\(emoji)": FieldValue.arrayUnion([userID])
            ])
            return
        }
        
        // Check if user already reacted with this emoji
        if var userIDs = reactions[emoji], userIDs.contains(userID) {
            // Remove reaction
            try await messageRef.updateData([
                "reactions.\(emoji)": FieldValue.arrayRemove([userID])
            ])
        } else {
            // Add reaction
            try await messageRef.updateData([
                "reactions.\(emoji)": FieldValue.arrayUnion([userID])
            ])
        }
    }
    
    func removeEmptyReactions(messageID: String, conversationID: String) async throws {
        let messageRef = db.collection("conversations")
            .document(conversationID)
            .collection("messages")
            .document(messageID)
        
        let document = try await messageRef.getDocument()
        
        guard var reactions = document.data()?["reactions"] as? [String: [String]] else {
            return
        }
        
        // Remove emojis with no users
        reactions = reactions.filter { !$0.value.isEmpty }
        
        try await messageRef.updateData([
            "reactions": reactions
        ])
    }
}
