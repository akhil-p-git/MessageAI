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
            
            ContactsView()
                .tabItem {
                    Label("Contacts", systemImage: "person.2")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .onAppear {
            if let currentUser = authViewModel.currentUser {
                PresenceService.shared.startPresenceUpdates(
                    userID: currentUser.id,
                    showOnlineStatus: currentUser.showOnlineStatus
                )
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
