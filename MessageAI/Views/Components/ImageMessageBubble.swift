import SwiftUI

struct ImageMessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    @State private var showFullScreen = false
    @State private var showReactionPicker = false
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Image
                if let urlString = message.mediaURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 200, height: 200)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: 250, maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onTapGesture {
                                    showFullScreen = true
                                }
                                .contextMenu {
                                    Button(action: {
                                        showReactionPicker = true
                                    }) {
                                        Label("Add Reaction", systemImage: "face.smiling")
                                    }
                                }
                                .onLongPressGesture {
                                    showReactionPicker = true
                                }
                        case .failure(_):
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 200, height: 200)
                                
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                    Text("Failed to load")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
                // Caption if exists
                if !message.content.isEmpty {
                    Text(message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                        .foregroundColor(isCurrentUser ? .white : .primary)
                        .cornerRadius(12)
                }
                
                // Reactions
                MessageReactionsView(message: message, isCurrentUser: isCurrentUser)
                
                // Timestamp
                HStack(spacing: 4) {
                    Text(formattedTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if isCurrentUser {
                        Image(systemName: statusIcon)
                            .font(.caption2)
                            .foregroundColor(statusColor)
                    }
                }
            }
            .overlay(alignment: isCurrentUser ? .topLeading : .topTrailing) {
                if showReactionPicker {
                    ReactionPickerView(message: message) { emoji in
                        Task {
                            await handleReaction(emoji)
                        }
                        withAnimation {
                            showReactionPicker = false
                        }
                    }
                    .offset(y: -60)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            if !isCurrentUser { Spacer() }
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            if let urlString = message.mediaURL, let url = URL(string: urlString) {
                FullScreenImageView(imageURL: url)
            }
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: message.timestamp)
    }
    
    private var statusIcon: String {
        switch message.status {
        case .sending:
            return "clock"
        case .sent:
            return "checkmark"
        case .delivered:
            return "checkmark.circle"
        case .read:
            return "checkmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch message.status {
        case .sending:
            return .gray
        case .sent:
            return .gray
        case .delivered:
            return .gray
        case .read:
            return .blue
        }
    }
    
    private func handleReaction(_ emoji: String) async {
        guard let currentUserID = authViewModel.currentUser?.id else { return }
        
        do {
            try await ReactionService.shared.toggleReaction(
                messageID: message.id,
                conversationID: message.conversationID,
                emoji: emoji,
                userID: currentUserID
            )
            
            try await ReactionService.shared.removeEmptyReactions(
                messageID: message.id,
                conversationID: message.conversationID
            )
        } catch {
            print("❌ Error toggling reaction: \(error)")
        }
    }
}

#Preview {
    VStack {
        ImageMessageBubble(
            message: Message(
                id: "1",
                conversationID: "conv1",
                senderID: "user1",
                content: "Check this out!",
                mediaURL: "https://picsum.photos/300/200"
            ),
            isCurrentUser: true
        )
        .environmentObject(AuthViewModel())
    }
    .padding()
}
