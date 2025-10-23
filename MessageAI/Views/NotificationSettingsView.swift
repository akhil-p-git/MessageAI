import SwiftUI

struct NotificationSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("messageNotifications") private var messageNotifications = true
    @AppStorage("groupNotifications") private var groupNotifications = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("vibrationEnabled") private var vibrationEnabled = true
    
    var body: some View {
        List {
            Section {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
            } footer: {
                Text("Allow MessageAI to send you notifications")
            }
            
            Section("Message Notifications") {
                Toggle("Direct Messages", isOn: $messageNotifications)
                    .disabled(!notificationsEnabled)
                
                Toggle("Group Messages", isOn: $groupNotifications)
                    .disabled(!notificationsEnabled)
            }
            
            Section("Alert Style") {
                Toggle("Sound", isOn: $soundEnabled)
                    .disabled(!notificationsEnabled)
                
                Toggle("Vibration", isOn: $vibrationEnabled)
                    .disabled(!notificationsEnabled)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
