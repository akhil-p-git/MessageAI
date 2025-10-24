import Foundation
import FirebaseFirestore
import Combine

@MainActor
class TypingIndicatorService: ObservableObject {
    static let shared = TypingIndicatorService()
    
    private var typingTimeoutTasks: [String: Task<Void, Never>] = [:]
    private let typingTimeout: TimeInterval = 3.0
    
    private init() {}
    
    // MARK: - Set Typing Status
    
    func setTyping(conversationID: String, userID: String, userName: String, isTyping: Bool) {
        print("⌨️  Setting typing: \(isTyping) for \(userName) in conversation \(conversationID.prefix(8))...")
        
        let db = Firestore.firestore()
        
        // Cancel existing timeout for this conversation
        typingTimeoutTasks[conversationID]?.cancel()
        
        Task {
            do {
                if isTyping {
                    // Add user to typing array
                    try await db.collection("conversations")
                        .document(conversationID)
                        .updateData([
                            "typingUsers": FieldValue.arrayUnion([userID]),
                            "typing_\(userID)": Timestamp(date: Date())
                        ])
                    
                    print("   ✅ Added \(userName) to typing users")
                    
                    // Set timeout to auto-clear typing
                    typingTimeoutTasks[conversationID] = Task {
                        try? await Task.sleep(nanoseconds: UInt64(typingTimeout * 1_000_000_000))
                        
                        if !Task.isCancelled {
                            await clearTyping(conversationID: conversationID, userID: userID)
                        }
                    }
                    
                } else {
                    // Remove user from typing array
                    try await db.collection("conversations")
                        .document(conversationID)
                        .updateData([
                            "typingUsers": FieldValue.arrayRemove([userID]),
                            "typing_\(userID)": FieldValue.delete()
                        ])
                    
                    print("   ✅ Removed \(userName) from typing users")
                }
                
            } catch {
                print("   ❌ Error setting typing status: \(error.localizedDescription)")
            }
        }
    }
    
    func clearTyping(conversationID: String, userID: String) async {
        let db = Firestore.firestore()
        
        do {
            try await db.collection("conversations")
                .document(conversationID)
                .updateData([
                    "typingUsers": FieldValue.arrayRemove([userID]),
                    "typing_\(userID)": FieldValue.delete()
                ])
            
            print("   ✅ Cleared typing for user \(userID.prefix(8))...")
            
        } catch {
            // Silently fail - typing indicators are non-critical
            print("   ⚠️  Could not clear typing (non-critical): \(error.localizedDescription)")
        }
    }
    
    func clearAllTyping(conversationID: String, userID: String) {
        typingTimeoutTasks[conversationID]?.cancel()
        
        Task {
            await clearTyping(conversationID: conversationID, userID: userID)
        }
    }
}
