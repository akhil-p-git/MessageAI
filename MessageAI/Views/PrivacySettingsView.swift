import SwiftUI

struct PrivacySettingsView: View {
    @AppStorage("showOnlineStatus") private var showOnlineStatus = true
    @AppStorage("showLastSeen") private var showLastSeen = true
    @AppStorage("showProfilePhoto") private var showProfilePhoto = true
    @AppStorage("readReceipts") private var readReceipts = true
    
    var body: some View {
        List {
            Section {
                Toggle("Show Online Status", isOn: $showOnlineStatus)
                Toggle("Show Last Seen", isOn: $showLastSeen)
            } footer: {
                Text("Control who can see when you're online and when you were last active")
            }
            
            Section {
                Toggle("Show Profile Photo", isOn: $showProfilePhoto)
            } footer: {
                Text("Control who can see your profile photo")
            }
            
            Section {
                Toggle("Read Receipts", isOn: $readReceipts)
            } footer: {
                Text("Let others know when you've read their messages")
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PrivacySettingsView()
    }
}
