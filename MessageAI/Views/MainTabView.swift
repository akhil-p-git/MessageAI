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
            List {
                // User Info Section
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 70, height: 70)
                            .overlay(
                                Text(authViewModel.currentUser?.displayName.prefix(1).uppercased() ?? "?")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authViewModel.currentUser?.displayName ?? "Unknown")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text(authViewModel.currentUser?.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Settings Section
                Section("Settings") {
                    NavigationLink(destination: EditProfileView()) {
                        Label("Edit Profile", systemImage: "person.circle")
                    }
                    
                    NavigationLink(destination: NotificationsSettingsView()) {
                        Label("Notifications", systemImage: "bell")
                    }
                    
                    NavigationLink(destination: PrivacySettingsView()) {
                        Label("Privacy", systemImage: "lock.shield")
                    }
                }
                
                // About Section
                Section("About") {
                    NavigationLink(destination: HelpSupportView()) {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }
                    
                    NavigationLink(destination: TermsOfServiceView()) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                }
                
                // Sign Out Section
                Section {
                    Button(action: {
                        authViewModel.signOut()
                    }) {
                        HStack {
                            Spacer()
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

// MARK: - Placeholder Views for Settings

struct NotificationsSettingsView: View {
    var body: some View {
        Text("Notifications Settings")
            .navigationTitle("Notifications")
    }
}

struct PrivacySettingsView: View {
    var body: some View {
        Text("Privacy Settings")
            .navigationTitle("Privacy")
    }
}

struct HelpSupportView: View {
    var body: some View {
        Text("Help & Support")
            .navigationTitle("Help & Support")
    }
}

struct TermsOfServiceView: View {
    var body: some View {
        Text("Terms of Service")
            .navigationTitle("Terms of Service")
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
