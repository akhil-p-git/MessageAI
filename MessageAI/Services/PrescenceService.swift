import Foundation
import FirebaseFirestore

@MainActor
class PresenceService {
    static let shared = PresenceService()
    
    private let db = Firestore.firestore()
    private var presenceTask: Task<Void, Never>?
    
    private init() {}
    
    func setUserOnline(userID: String, isOnline: Bool, showOnlineStatus: Bool = true) async {
        do {
            // Only show as online if privacy setting allows
            var updateData: [String: Any] = [
                "isOnline": showOnlineStatus && isOnline
            ]
            
            if !isOnline {
                updateData["lastSeen"] = Timestamp(date: Date())
            }
            
            try await db.collection("users")
                .document(userID)
                .updateData(updateData)
            
            print("✅ Updated presence: \(showOnlineStatus && isOnline ? "online" : "offline") (privacy: \(showOnlineStatus))")
        } catch {
            print("❌ Error updating presence: \(error)")
        }
    }
    
    func startPresenceUpdates(userID: String, showOnlineStatus: Bool = true) {
        // Cancel existing task if any
        presenceTask?.cancel()
        
        presenceTask = Task {
            while !Task.isCancelled {
                await setUserOnline(userID: userID, isOnline: true, showOnlineStatus: showOnlineStatus)
                try? await Task.sleep(nanoseconds: 30_000_000_000) // Every 30 seconds
            }
        }
        
        print("👀 Started presence updates for \(userID.prefix(8))... (showOnline: \(showOnlineStatus))")
    }
    
    func stopPresenceUpdates(userID: String) {
        presenceTask?.cancel()
        presenceTask = nil
        
        Task {
            await setUserOnline(userID: userID, isOnline: false)
        }
        
        print("👋 Stopped presence updates for \(userID.prefix(8))...")
    }
}
