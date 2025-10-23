import SwiftUI

struct ReactionPickerView: View {
    let message: Message
    let onReactionSelected: (String) -> Void
    @EnvironmentObject var authViewModel: AuthViewModel
    
    private let reactions = ["❤️", "👍", "👎", "😂", "😮", "😢", "🙏", "🎉"]
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(reactions, id: \.self) { emoji in
                Button(action: {
                    onReactionSelected(emoji)
                }) {
                    ZStack {
                        Circle()
                            .fill(hasUserReacted(emoji) ? Color.blue.opacity(0.2) : Color(.systemGray6))
                            .frame(width: 44, height: 44)
                        
                        Text(emoji)
                            .font(.system(size: 24))
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private func hasUserReacted(_ emoji: String) -> Bool {
        guard let currentUserID = authViewModel.currentUser?.id,
              let userIDs = message.reactions[emoji] else {
            return false
        }
        return userIDs.contains(currentUserID)
    }
}

#Preview {
    ReactionPickerView(
        message: Message(
            id: "1",
            conversationID: "conv1",
            senderID: "user1",
            content: "Hello!"
        ),
        onReactionSelected: { _ in }
    )
    .environmentObject(AuthViewModel())
}
