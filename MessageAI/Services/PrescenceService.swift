import Foundation
import FirebaseFirestore
import Combine

@MainActor
class PresenceService {
    static let shared = PresenceService()
    
    private let db = Firestore.firestore()
    private var presenceTask: Task<Void, Never>?
    private var networkCancellable: AnyCancellable?
    private var currentUserID: String?
    private var currentShowOnlineStatus: Bool = true
    
    private init() {
        // Monitor network connectivity
        networkCancellable = NetworkMonitor.shared.$isConnected
            .sink { [weak self] isConnected in
                guard let self = self, let userID = self.currentUserID else { return }
                
                Task { @MainActor in
                    if isConnected {
                        print("🌐 Network restored - resuming presence updates")
                        await self.startPresenceUpdates(userID: userID, showOnlineStatus: self.currentShowOnlineStatus)
                    } else {
                        print("📡 Network lost - stopping presence updates")
                        self.presenceTask?.cancel()
                        self.presenceTask = nil
                        // Note: Can't update Firestore when offline, but Firebase will handle this
                    }
                }
            }
    }
    
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
        // Store current user info for network monitoring
        currentUserID = userID
        currentShowOnlineStatus = showOnlineStatus
        
        // Cancel existing task if any
        presenceTask?.cancel()
        
        // Only start if network is connected
        guard NetworkMonitor.shared.isConnected else {
            print("⚠️ Cannot start presence updates - offline")
            return
        }
        
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
        currentUserID = nil
        
        Task {
            await setUserOnline(userID: userID, isOnline: false)
        }
        
        print("👋 Stopped presence updates for \(userID.prefix(8))...")
    }
}
