import Foundation
import FirebaseFirestore

@MainActor
class BlockUserService {
    static let shared = BlockUserService()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    func blockUser(blockerID: String, blockedID: String, conversationID: String?) async throws {
        // 1. Add to blocked users
        try await db.collection("users")
            .document(blockerID)
            .updateData([
                "blockedUsers": FieldValue.arrayUnion([blockedID])
            ])
        
        // 2. Remove from contacts if they're a contact
        try await db.collection("users")
            .document(blockerID)
            .updateData([
                "contacts": FieldValue.arrayRemove([blockedID])
            ])
        
        // 3. Delete the conversation if provided
        if let conversationID = conversationID {
            try await db.collection("conversations")
                .document(conversationID)
                .delete()
        }
        
        print("✅ Blocked user: \(blockedID), removed from contacts, deleted conversation")
    }
    
    func unblockUser(blockerID: String, blockedID: String) async throws {
        try await db.collection("users")
            .document(blockerID)
            .updateData([
                "blockedUsers": FieldValue.arrayRemove([blockedID])
            ])
        
        print("✅ Unblocked user: \(blockedID)")
    }
    
    func reportUser(reporterID: String, reportedID: String, reason: String) async throws {
        let reportData: [String: Any] = [
            "reporterID": reporterID,
            "reportedID": reportedID,
            "reason": reason,
            "timestamp": Timestamp(date: Date())
        ]
        
        try await db.collection("reports")
            .addDocument(data: reportData)
        
        print("✅ Reported user: \(reportedID)")
    }
    
    func isBlocked(blockerID: String, blockedID: String) async throws -> Bool {
        let document = try await db.collection("users")
            .document(blockerID)
            .getDocument()
        
        let blockedUsers = document.data()?["blockedUsers"] as? [String] ?? []
        return blockedUsers.contains(blockedID)
    }
}
