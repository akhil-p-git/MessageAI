import SwiftUI

struct BlockedUsersView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var blockedUsers: [User] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView()
                } else if blockedUsers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "hand.raised.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No blocked users")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(blockedUsers) { user in
                            HStack(spacing: 12) {
                                ProfileImageView(
                                    url: user.profilePictureURL,
                                    size: 44,
                                    fallbackText: user.displayName
                                )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.displayName)
                                        .font(.body)
                                    
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button("Unblock") {
                                    Task {
                                        await unblockUser(user)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(.blue)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Blocked Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadBlockedUsers()
            }
        }
    }
    
    private func loadBlockedUsers() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        isLoading = true
        
        var users: [User] = []
        
        for blockedID in currentUser.blockedUsers {
            if let user = try? await AuthService.shared.fetchUserDocument(userId: blockedID) {
                users.append(user)
            }
        }
        
        await MainActor.run {
            self.blockedUsers = users
            self.isLoading = false
        }
    }
    
    private func unblockUser(_ user: User) async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        do {
            try await BlockUserService.shared.unblockUser(
                blockerID: currentUser.id,
                blockedID: user.id
            )
            
            await MainActor.run {
                blockedUsers.removeAll { $0.id == user.id }
            }
        } catch {
            print("❌ Error unblocking user: \(error)")
        }
    }
}

#Preview {
    BlockedUsersView()
        .environmentObject(AuthViewModel())
}
