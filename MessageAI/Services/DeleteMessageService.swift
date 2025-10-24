import Foundation
import FirebaseFirestore

@MainActor
class DeleteMessageService {
    static let shared = DeleteMessageService()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    func deleteMessageForMe(messageID: String, conversationID: String, userID: String) async throws {
        print("🔥 DeleteMessageService: Deleting message for user")
        print("   Message ID: \(messageID)")
        print("   Conversation ID: \(conversationID)")
        print("   User ID: \(userID)")
        
        // Mark as deleted for this user only
        try await db.collection("conversations")
            .document(conversationID)
            .collection("messages")
            .document(messageID)
            .updateData([
                "deletedFor": FieldValue.arrayUnion([userID])
            ])
        
        print("✅ DeleteMessageService: Successfully updated Firestore")
        print("   Message \(messageID) now has \(userID) in deletedFor array")
    }
    
    func deleteMessageForEveryone(messageID: String, conversationID: String) async throws {
        // Replace content with deleted message
        try await db.collection("conversations")
            .document(conversationID)
            .collection("messages")
            .document(messageID)
            .updateData([
                "content": "This message was deleted",
                "deletedForEveryone": true,
                "type": "text",
                "mediaURL": FieldValue.delete()
            ])
        
        print("✅ Deleted message for everyone: \(messageID)")
    }
}
