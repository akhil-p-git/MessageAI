import Foundation
import FirebaseFirestore

@MainActor
class TypingIndicatorService {
    static let shared = TypingIndicatorService()
    
    private let db = Firestore.firestore()
    private var typingTimer: Timer?
    
    private init() {}
    
    func setTyping(conversationID: String, userID: String, isTyping: Bool) {
        // Cancel existing timer
        typingTimer?.invalidate()
        
        if isTyping {
            // Add user to typing list
            db.collection("conversations").document(conversationID).updateData([
                "typingUsers": FieldValue.arrayUnion([userID])
            ])
            
            // Auto-clear after 3 seconds
            typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.clearTyping(conversationID: conversationID, userID: userID)
            }
        } else {
            clearTyping(conversationID: conversationID, userID: userID)
        }
    }
    
    private func clearTyping(conversationID: String, userID: String) {
        db.collection("conversations").document(conversationID).updateData([
            "typingUsers": FieldValue.arrayRemove([userID])
        ])
    }
    
    func clearAllTyping(conversationID: String, userID: String) {
        typingTimer?.invalidate()
        clearTyping(conversationID: conversationID, userID: userID)
    }
}
