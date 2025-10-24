import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthService {
    static let shared = AuthService()
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Authentication
    
    func signUp(email: String, password: String, displayName: String) async throws -> User {
        let authResult = try await auth.createUser(withEmail: email, password: password)
        
        let user = User(
            id: authResult.user.uid,
            email: email,
            displayName: displayName
        )
        
        try await db.collection("users").document(user.id).setData(user.toDictionary())
        
        return user
    }
    
    func signIn(email: String, password: String) async throws -> User {
        let authResult = try await auth.signIn(withEmail: email, password: password)
        let user = try await fetchUserDocument(userId: authResult.user.uid)
        return user
    }
    
    func signOut() throws {
        try auth.signOut()
    }
    
    func getCurrentUser() async throws -> User? {
        guard let firebaseUser = auth.currentUser else {
            return nil
        }
        
        return try await fetchUserDocument(userId: firebaseUser.uid)
    }
    
    // MARK: - User Management
    
    func fetchUserDocument(userId: String) async throws -> User {
        let document = try await db.collection("users").document(userId).getDocument()
        
        guard let data = document.data(),
              let user = User.fromDictionary(data) else {
            throw NSError(domain: "AuthService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        
        return user
    }
    
    func fetchAllUsers() async throws -> [User] {
        let snapshot = try await db.collection("users").getDocuments()
        
        var users: [User] = []
        
        for document in snapshot.documents {
            if let user = User.fromDictionary(document.data()) {
                users.append(user)
            }
        }
        
        return users
    }
    
    func findUserByEmail(email: String) async throws -> User? {
        print("🔍 AuthService: Searching for user with email: \(email)")
        
        let snapshot = try await db.collection("users")
            .whereField("email", isEqualTo: email.lowercased())
            .limit(to: 1)
            .getDocuments()
        
        print("📊 AuthService: Found \(snapshot.documents.count) documents")
        
        guard let document = snapshot.documents.first,
              let user = User.fromDictionary(document.data()) else {
            print("❌ AuthService: No user found or failed to parse")
            return nil
        }
        
        print("✅ AuthService: Found user: \(user.displayName)")
        return user
    }
    
    func updateUserProfile(userId: String, displayName: String?, profilePictureURL: String?) async throws {
        var updateData: [String: Any] = [:]
        
        if let displayName = displayName {
            updateData["displayName"] = displayName
        }
        
        if let profilePictureURL = profilePictureURL {
            updateData["profilePictureURL"] = profilePictureURL
        }
        
        if !updateData.isEmpty {
            try await db.collection("users").document(userId).updateData(updateData)
        }
    }
    
    func searchUsers(query: String) async throws -> [User] {
        let allUsers = try await fetchAllUsers()
        
        return allUsers.filter { user in
            user.displayName.localizedCaseInsensitiveContains(query) ||
            user.email.localizedCaseInsensitiveContains(query)
        }
    }
}
