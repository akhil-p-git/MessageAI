import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ConversationListView()
                .tabItem {
                    Label("Chats", systemImage: "message")
                }
                .tag(0)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(1)
        }
        .onAppear {
            if let currentUser = authViewModel.currentUser {
                PresenceService.shared.startPresenceUpdates(userID: currentUser.id)
                InAppNotificationService.shared.startListening(userID: currentUser.id)
            }
        }
        .onDisappear {
            if let currentUser = authViewModel.currentUser {
                Task {
                    await PresenceService.shared.setUserOnline(userID: currentUser.id, isOnline: false)
                }
            }
            InAppNotificationService.shared.stopListening()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
