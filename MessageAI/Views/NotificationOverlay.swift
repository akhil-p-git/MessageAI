import SwiftUI

struct NotificationOverlay: View {
    @StateObject private var notificationService = InAppNotificationService.shared
    @Binding var selectedConversationID: String?
    
    var body: some View {
        VStack {
            if notificationService.showNotification {
                NotificationBanner(
                    title: notificationService.notificationTitle,
                    message: notificationService.notificationMessage,
                    onTap: {
                        selectedConversationID = notificationService.conversationID
                        notificationService.showNotification = false
                    },
                    onDismiss: {
                        notificationService.showNotification = false
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(), value: notificationService.showNotification)
            }
            
            Spacer()
        }
        .padding(.top, 50)
        .padding(.horizontal)
    }
}

struct NotificationBanner: View {
    let title: String
    let message: String
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(title.prefix(1).uppercased())
                        .foregroundColor(.white)
                        .font(.headline)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .onTapGesture(perform: onTap)
    }
}

#Preview {
    NotificationOverlay(selectedConversationID: .constant(nil))
}
