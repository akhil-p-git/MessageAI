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
        Task {
            await checkAuthState()
        }
    }
    
    func checkAuthState() async {
        isLoading = true
        
        do {
            if let firebaseUser = Auth.auth().currentUser {
                let user = try await authService.fetchUserDocument(userId: firebaseUser.uid)
                self.currentUser = user
                
                // Start continuous presence updates
                await PresenceService.shared.startPresenceUpdates(
                    userID: user.id,
                    showOnlineStatus: user.showOnlineStatus
                )
            } else {
                self.currentUser = nil
            }
        } catch {
            print("Error fetching user: \(error)")
            self.currentUser = nil
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await authService.signUp(email: email, password: password, displayName: displayName)
            self.currentUser = user
            
            // Start continuous presence updates after sign up
            await PresenceService.shared.startPresenceUpdates(
                userID: user.id,
                showOnlineStatus: user.showOnlineStatus
            )
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
            
            // Start continuous presence updates after sign in
            await PresenceService.shared.startPresenceUpdates(
                userID: user.id,
                showOnlineStatus: user.showOnlineStatus
            )
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signOut() {
        do {
            // Stop presence updates and set user offline before signing out
            if let userID = currentUser?.id {
                Task {
                    await PresenceService.shared.stopPresenceUpdates(userID: userID)
                }
            }
            
            try authService.signOut()
            self.currentUser = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
