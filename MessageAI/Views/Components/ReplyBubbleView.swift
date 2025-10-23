import SwiftUI

struct ReplyBubbleView: View {
    let replyToContent: String
    let replyToSenderName: String
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(isCurrentUser ? Color.white.opacity(0.5) : Color.blue.opacity(0.5))
                .frame(width: 3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(replyToSenderName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(isCurrentUser ? .white.opacity(0.8) : .blue)
                
                Text(replyToContent)
                    .font(.caption)
                    .foregroundColor(isCurrentUser ? .white.opacity(0.7) : .secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrentUser ? Color.white.opacity(0.2) : Color(.systemGray6))
        )
    }
}
