import SwiftUI

struct ReplyMessagePreview: View {
    let replyToContent: String
    let replyToSenderName: String
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.blue)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(replyToSenderName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                Text(replyToContent)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
    }
}
