import Foundation
import FirebaseFirestore

@MainActor
class PresenceService {
    static let shared = PresenceService()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    // Update typing status
    func setTyping(conversationID: String, userID: String, isTyping: Bool) async {
        do {
            if isTyping {
                try await db.collection("conversations")
                    .document(conversationID)
                    .collection("typing")
                    .document(userID)
                    .setData([
                        "isTyping": true,
                        "timestamp": Date()
                    ])
            } else {
                try await db.collection("conversations")
                    .document(conversationID)
                    .collection("typing")
                    .document(userID)
                    .delete()
            }
        } catch {
            print("Error updating typing status: \(error)")
        }
    }
    
    // Update user online status
    func setUserOnline(userID: String, isOnline: Bool) async {
        do {
            try await db.collection("users").document(userID).updateData([
                "isOnline": isOnline,
                "lastSeen": Date()
            ])
        } catch {
            print("Error updating online status: \(error)")
        }
    }
    
    // Listen to typing status
    func listenToTyping(conversationID: String, completion: @escaping ([String]) -> Void) -> ListenerRegistration {
        return db.collection("conversations")
            .document(conversationID)
            .collection("typing")
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else {
                    print("Error listening to typing: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                
                let typingUserIDs = snapshot.documents.compactMap { doc -> String? in
                    guard let isTyping = doc.data()["isTyping"] as? Bool,
                          isTyping else {
                        return nil
                    }
                    return doc.documentID
                }
                
                completion(typingUserIDs)
            }
    }
}
