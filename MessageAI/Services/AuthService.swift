import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthService {
    static let shared = AuthService()
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func signUp(email: String, password: String, displayName: String) async throws -> User {
        let result = try await auth.createUser(withEmail: email, password: password)
        
        let user = User(
            id: result.user.uid,
            email: email,
            displayName: displayName,
            isOnline: true,
            lastSeen: Date()
        )
        
        try await createUserDocument(user: user)
        return user
    }
    
    func signIn(email: String, password: String) async throws -> User {
        let result = try await auth.signIn(withEmail: email, password: password)
        let user = try await fetchUserDocument(userId: result.user.uid)
        
        // Update online status
        try await db.collection("users").document(result.user.uid).updateData([
            "isOnline": true,
            "lastSeen": Date()
        ])
        
        return user
    }
    
    func signOut() throws {
        try auth.signOut()
    }
    
    func getCurrentUser() -> FirebaseAuth.User? {
        return auth.currentUser
    }
    
    func createUserDocument(user: User) async throws {
        try await db.collection("users").document(user.id).setData(user.toDictionary())
    }
    
    func fetchUserDocument(userId: String) async throws -> User {
        let document = try await db.collection("users").document(userId).getDocument()
        
        guard let data = document.data(),
              let user = User.fromDictionary(data) else {
            throw NSError(domain: "AuthService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        
        return user
    }
}
