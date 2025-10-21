import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var notificationService = InAppNotificationService.shared
    @State private var selectedConversationID: String?
    
    var body: some View {
        ZStack {
            TabView {
                ConversationListView(selectedConversationID: $selectedConversationID)
                    .tabItem {
                        Label("Chats", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
            }
            
            // Notification overlay
            NotificationOverlay(selectedConversationID: $selectedConversationID)
                .allowsHitTesting(true)
        }
        .onAppear {
            if let userID = authViewModel.currentUser?.id {
                notificationService.startListening(userID: userID)
            }
        }
        .onDisappear {
            notificationService.stopListening()
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                if let user = authViewModel.currentUser {
                    Text(user.displayName)
                        .font(.title2)
                        .bold()
                    
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Button("Sign Out") {
                    authViewModel.signOut()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
