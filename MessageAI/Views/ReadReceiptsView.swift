import SwiftUI
import FirebaseFirestore

struct ReadReceiptsView: View {
    let message: Message
    @Environment(\.dismiss) private var dismiss
    @State private var users: [User] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if users.isEmpty {
                    Text("No read receipts yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(users) { user in
                        HStack(spacing: 12) {
                            ProfileImageView(
                                url: user.profilePictureURL,
                                size: 40,
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
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Read By")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadUsers()
            }
        }
    }
    
    private func loadUsers() async {
        isLoading = true
        
        var loadedUsers: [User] = []
        
        for userID in message.readBy {
            if let user = try? await AuthService.shared.fetchUserDocument(userId: userID) {
                loadedUsers.append(user)
            }
        }
        
        await MainActor.run {
            self.users = loadedUsers
            self.isLoading = false
        }
    }
}

#Preview {
    ReadReceiptsView(
        message: Message(
            id: "1",
            conversationID: "conv1",
            senderID: "user1",
            content: "Hello!",
            readBy: ["user2", "user3"]
        )
    )
}
