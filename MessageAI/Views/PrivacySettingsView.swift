import SwiftUI
import FirebaseFirestore

struct PrivacySettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showOnlineStatus = true
    @State private var showLastSeen = true
    @State private var showProfilePhoto = true
    @State private var readReceipts = true
    @State private var isLoading = false
    @State private var showSavedMessage = false
    
    var body: some View {
        List {
            Section {
                Toggle("Show Online Status", isOn: $showOnlineStatus)
                    .onChange(of: showOnlineStatus) { oldValue, newValue in
                        Task {
                            await updateOnlineStatusSetting(newValue)
                        }
                    }
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
            
            if showSavedMessage {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Settings saved")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        guard let currentUser = authViewModel.currentUser else { return }
        showOnlineStatus = currentUser.showOnlineStatus
        print("📋 Loaded privacy settings - showOnlineStatus: \(showOnlineStatus)")
    }
    
    private func updateOnlineStatusSetting(_ newValue: Bool) async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        isLoading = true
        
        let db = Firestore.firestore()
        
        do {
            print("\n🔒 Updating online status privacy setting...")
            print("   User: \(currentUser.displayName)")
            print("   Show online: \(newValue)")
            
            // Update Firestore user document
            try await db.collection("users")
                .document(currentUser.id)
                .updateData([
                    "showOnlineStatus": newValue
                ])
            
            print("   ✅ Updated user document")
            
            // Update local user object
            await MainActor.run {
                currentUser.showOnlineStatus = newValue
                authViewModel.currentUser = currentUser
            }
            
            // Update presence to reflect new setting
            if !newValue {
                // If hiding online status, appear offline
                try await db.collection("users")
                    .document(currentUser.id)
                    .updateData([
                        "isOnline": false
                    ])
                print("   ✅ Set to appear offline")
            } else {
                // If showing online status, set to online
                try await db.collection("users")
                    .document(currentUser.id)
                    .updateData([
                        "isOnline": true
                    ])
                print("   ✅ Set to appear online")
            }
            
            // Show saved message
            await MainActor.run {
                showSavedMessage = true
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        showSavedMessage = false
                    }
                }
            }
            
            print("   ✅ Privacy setting saved!\n")
            
        } catch {
            print("   ❌ Error updating privacy setting: \(error.localizedDescription)\n")
        }
        
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        PrivacySettingsView()
    }
}
