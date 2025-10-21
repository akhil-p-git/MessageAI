import SwiftUI

struct NotificationBannerView: View {
    let notification: NotificationItem
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "message.fill")
                        .foregroundColor(.blue)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(notification.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
        .onTapGesture {
            onTap()
        }
    }
}

struct NotificationOverlay: View {
    @ObservedObject var notificationService = InAppNotificationService.shared
    @Binding var selectedConversationID: String?
    
    var body: some View {
        VStack {
            ForEach(notificationService.notifications) { notification in
                NotificationBannerView(
                    notification: notification,
                    onTap: {
                        selectedConversationID = notification.conversationID
                        notificationService.dismissNotification(id: notification.id)
                    },
                    onDismiss: {
                        notificationService.dismissNotification(id: notification.id)
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(), value: notificationService.notifications.count)
            }
            
            Spacer()
        }
        .padding(.top, 50)
    }
}
