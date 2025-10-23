import SwiftUI

struct MessageReactionsView: View {
    let message: Message
    let isCurrentUser: Bool
    @State private var showReactionDetails = false
    
    var body: some View {
        if !message.reactions.isEmpty {
            HStack(spacing: 4) {
                ForEach(sortedReactionKeys(), id: \.self) { emoji in
                    if let userIDs = message.reactions[emoji], !userIDs.isEmpty {
                        HStack(spacing: 2) {
                            Text(emoji)
                                .font(.system(size: 14))
                            
                            if userIDs.count > 1 {
                                Text("\(userIDs.count)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(.systemGray5))
                        )
                        .onTapGesture {
                            showReactionDetails = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showReactionDetails) {
                ReactionDetailsView(message: message)
            }
        }
    }
    
    private func sortedReactionKeys() -> [String] {
        return message.reactions.keys.sorted()
    }
}

#Preview {
    VStack {
        MessageReactionsView(
            message: Message(
                id: "1",
                conversationID: "conv1",
                senderID: "user1",
                content: "Hello!",
                reactions: ["❤️": ["user1", "user2"], "👍": ["user3"]]
            ),
            isCurrentUser: true
        )
    }
    .padding()
}
