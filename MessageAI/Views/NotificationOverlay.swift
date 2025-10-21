import SwiftUI

struct NotificationOverlay: View {
    @StateObject private var notificationService = InAppNotificationService.shared
    @Binding var selectedConversationID: String?
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(notificationService.notifications) { notification in
                NotificationBanner(
                    notification: notification,
                    onTap: {
                        selectedConversationID = notification.conversationID
                        notificationService.dismissNotification(id: notification.id)
                    },
                    onDismiss: {
                        notificationService.dismissNotification(id: notification.id)
                    }
                )
            }
            
            Spacer()
        }
        .padding(.top, 50)
        .padding(.horizontal)
    }
}

struct NotificationBanner: View {
    let notification: NotificationItem
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(notification.title.prefix(1).uppercased())
                        .foregroundColor(.white)
                        .font(.headline)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(notification.message)
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
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .onTapGesture(perform: onTap)
    }
}
