import Foundation
import FirebaseAuth
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var isAuthenticated: Bool {
        currentUser != nil
    }
    
    private let authService = AuthService.shared
    
    init() {
        checkAuthState()
    }
    
    func checkAuthState() {
        isLoading = true
        if let firebaseUser = authService.getCurrentUser() {
            Task {
                do {
                    let user = try await authService.fetchUserDocument(userId: firebaseUser.uid)
                    self.currentUser = user
                    Task {
                        await PresenceService.shared.setUserOnline(userID: user.id, isOnline: true)
                    }
                } catch {
                    print("Error fetching user: \(error)")
                }
                self.isLoading = false
            }
        } else {
            isLoading = false
        }
    }
    
    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await authService.signUp(email: email, password: password, displayName: displayName)
            self.currentUser = user
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await authService.signIn(email: email, password: password)
            self.currentUser = user
            
            // Set user online after successful sign in
            Task {
                await PresenceService.shared.setUserOnline(userID: user.id, isOnline: true)
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signOut() {
        do {
            if let currentUser = currentUser {
                Task {
                    await PresenceService.shared.setUserOnline(userID: currentUser.id, isOnline: false)
                }
            }
            try authService.signOut()
            currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
