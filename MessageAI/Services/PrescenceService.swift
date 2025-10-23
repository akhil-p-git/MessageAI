import Foundation
import FirebaseFirestore

@MainActor
class PresenceService {
    static let shared = PresenceService()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    func setUserOnline(userID: String, isOnline: Bool) async {
        do {
            var updateData: [String: Any] = [
                "isOnline": isOnline
            ]
            
            if !isOnline {
                updateData["lastSeen"] = Timestamp(date: Date())
            }
            
            try await db.collection("users")
                .document(userID)
                .updateData(updateData)
            
            print("✅ Updated presence: \(isOnline ? "online" : "offline")")
        } catch {
            print("❌ Error updating presence: \(error)")
        }
    }
    
    func startPresenceUpdates(userID: String) {
        Task {
            while true {
                await setUserOnline(userID: userID, isOnline: true)
                try? await Task.sleep(nanoseconds: 30_000_000_000) // Every 30 seconds
            }
        }
    }
}
