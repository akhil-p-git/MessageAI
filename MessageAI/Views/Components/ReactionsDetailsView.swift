import SwiftUI
import FirebaseFirestore

struct ReactionDetailsView: View {
    let message: Message
    @Environment(\.dismiss) private var dismiss
    @State private var reactionUsers: [String: [User]] = [:]
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(message.reactions.keys.sorted()), id: \.self) { emoji in
                    if let userIDs = message.reactions[emoji], !userIDs.isEmpty {
                        Section(header: Text(emoji).font(.title)) {
                            if let users = reactionUsers[emoji] {
                                ForEach(users) { user in
                                    HStack(spacing: 12) {
                                        ProfileImageView(
                                            url: user.profilePictureURL,
                                            size: 40,
                                            fallbackText: user.displayName
                                        )
                                        
                                        Text(user.displayName)
                                            .font(.body)
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                            } else {
                                ProgressView()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadReactionUsers()
            }
        }
    }
    
    private func loadReactionUsers() async {
        isLoading = true
        var usersDict: [String: [User]] = [:]
        
        for (emoji, userIDs) in message.reactions {
            var users: [User] = []
            
            for userID in userIDs {
                if let user = try? await AuthService.shared.fetchUserDocument(userId: userID) {
                    users.append(user)
                }
            }
            
            usersDict[emoji] = users
        }
        
        await MainActor.run {
            self.reactionUsers = usersDict
            self.isLoading = false
        }
    }
}

#Preview {
    ReactionDetailsView(
        message: Message(
            id: "1",
            conversationID: "conv1",
            senderID: "user1",
            content: "Hello!",
            reactions: ["❤️": ["user1", "user2"], "👍": ["user3"]]
        )
    )
}
