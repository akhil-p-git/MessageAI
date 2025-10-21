import SwiftUI
import SwiftData
import FirebaseFirestore

struct ChatView: View {
    let conversation: Conversation
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var messageText = ""
    @State private var messages: [Message] = []
    @State private var listener: ListenerRegistration?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages ScrollView
            ScrollViewReader { proxy in
                ScrollView {
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else if messages.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No messages yet")
                                .foregroundColor(.secondary)
                            Text("Send a message to start the conversation")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(
                                    message: message,
                                    isCurrentUser: message.senderID == authViewModel.currentUser?.id,
                                    isGroupChat: conversation.isGroup
                                )
                                .id(message.id)
                            }
                        }
                        .padding()
                    }
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: messages) { _, _ in
                    // Mark messages as read when they appear on screen
                    updateMessageStatuses()
                }
            }
            
            // Input Bar
            HStack(spacing: 12) {
                TextField("Message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(messageText.isEmpty ? .gray : .blue)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle(conversation.isGroup ? (conversation.name ?? "Group Chat") : "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if conversation.isGroup {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: GroupInfoView(conversation: conversation)) {
                        Image(systemName: "info.circle")
                    }
                }
            }
        }
        .onAppear {
            InAppNotificationService.shared.activeConversationID = conversation.id
            startListening()
            
            // Call async functions properly
            Task {
                await markAsRead()
                await markMessagesAsDelivered()
            }
        }
        .onDisappear {
            InAppNotificationService.shared.activeConversationID = nil
            listener?.remove()
        }
    }
    
    private func startListening() {
        let db = Firestore.firestore()
        
        listener = db.collection("conversations")
            .document(conversation.id)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else {
                    print("Error listening to messages: \(error?.localizedDescription ?? "Unknown")")
                    isLoading = false
                    return
                }
                
                var newMessages: [Message] = []
                
                for document in snapshot.documents {
                    var data = document.data()
                    
                    // Convert Firestore Timestamp to Date
                    if let timestamp = data["timestamp"] as? Timestamp {
                        data["timestamp"] = timestamp.dateValue()
                    }
                    
                    if let message = Message.fromDictionary(data) {
                        newMessages.append(message)
                    }
                }
                
                self.messages = newMessages
                self.isLoading = false
                
                // Automatically mark as read when new messages arrive while viewing
                Task {
                    await self.markAsRead()
                    await self.updateMessageStatuses()
                }
            }
    }
    
    private func sendMessage() {
        guard let currentUser = authViewModel.currentUser,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        
        let message = Message(
            id: UUID().uuidString,
            conversationID: conversation.id,
            senderID: currentUser.id,
            content: content,
            timestamp: Date(),
            status: .sent,
            type: .text
        )
        
        Task {
            let db = Firestore.firestore()
            
            do {
                var messageData = message.toDictionary()
                messageData["timestamp"] = Timestamp(date: message.timestamp)
                messageData["status"] = "sent"
                
                // Send message to Firestore
                try await db.collection("conversations")
                    .document(conversation.id)
                    .collection("messages")
                    .document(message.id)
                    .setData(messageData)
                
                // Update conversation's last message
                try await db.collection("conversations")
                    .document(conversation.id)
                    .updateData([
                        "lastMessage": content,
                        "lastMessageTime": Timestamp(date: Date()),
                        "lastSenderID": currentUser.id
                    ])
                
                print("✅ Message sent successfully")
            } catch {
                print("❌ Error sending message: \(error)")
            }
        }
    }
    
    private func markAsRead() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        let db = Firestore.firestore()
        
        do {
            try await db.collection("conversations")
                .document(conversation.id)
                .updateData([
                    "lastReadTime": Timestamp(date: Date())
                ])
            
            print("✅ Marked conversation as read")
        } catch {
            print("❌ Error marking as read: \(error)")
        }
    }
    
    private func markMessagesAsDelivered() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        let db = Firestore.firestore()
        
        // Give a small delay to ensure messages are loaded
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Update messages that are "sent" to "delivered" when conversation is opened
        for message in messages where message.senderID != currentUser.id && message.status == .sent {
            do {
                try await db.collection("conversations")
                    .document(conversation.id)
                    .collection("messages")
                    .document(message.id)
                    .updateData([
                        "status": "delivered"
                    ])
                
                print("✅ Marked message as delivered: \(message.id)")
            } catch {
                print("❌ Error marking as delivered: \(error)")
            }
        }
    }
    
    private func updateMessageStatuses() {
        guard let currentUser = authViewModel.currentUser else { return }
        
        Task {
            let db = Firestore.firestore()
            
            // Update messages from other users
            for message in messages where message.senderID != currentUser.id {
                // Check if current user already marked as read
                guard !message.readBy.contains(currentUser.id) else { continue }
                
                do {
                    // Add current user to readBy array
                    try await db.collection("conversations")
                        .document(conversation.id)
                        .collection("messages")
                        .document(message.id)
                        .updateData([
                            "readBy": FieldValue.arrayUnion([currentUser.id])
                        ])
                    
                    // For non-group chats, update status to "read"
                    if !conversation.isGroup {
                        try await db.collection("conversations")
                            .document(conversation.id)
                            .collection("messages")
                            .document(message.id)
                            .updateData([
                                "status": "read"
                            ])
                    }
                    
                    print("✅ Marked message as read: \(message.id)")
                } catch {
                    print("❌ Error updating message status: \(error)")
                }
            }
            
            // For group chats, check if all participants have read and update status
            if conversation.isGroup {
                await updateGroupChatReadStatus()
            }
        }
    }
    
    private func updateGroupChatReadStatus() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        let db = Firestore.firestore()
        
        // Get all messages sent by current user
        for message in messages where message.senderID == currentUser.id {
            // Check if all other participants have read the message
            let otherParticipants = conversation.participantIDs.filter { $0 != currentUser.id }
            let allRead = otherParticipants.allSatisfy { participantID in
                message.readBy.contains(participantID)
            }
            
            // Update status based on read state
            let newStatus: String
            if allRead {
                newStatus = "read"
            } else if !message.readBy.isEmpty {
                newStatus = "delivered"
            } else {
                newStatus = "sent"
            }
            
            // Only update if status changed
            if newStatus != message.statusRaw {
                do {
                    try await db.collection("conversations")
                        .document(conversation.id)
                        .collection("messages")
                        .document(message.id)
                        .updateData([
                            "status": newStatus
                        ])
                    
                    print("✅ Updated group message status to \(newStatus): \(message.id)")
                } catch {
                    print("❌ Error updating group message status: \(error)")
                }
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    let isGroupChat: Bool
    @State private var showReadReceipts = false
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .cornerRadius(18)
                    .onLongPressGesture {
                        if isCurrentUser && isGroupChat && !message.readBy.isEmpty {
                            showReadReceipts = true
                        }
                    }
                
                HStack(spacing: 4) {
                    Text(formattedTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    // Read receipt checkmarks (only for sent messages)
                    if isCurrentUser {
                        HStack(spacing: 2) {
                            Image(systemName: statusIcon)
                                .font(.caption2)
                                .foregroundColor(statusColor)
                            
                            // Show read count for group messages
                            if isGroupChat && !message.readBy.isEmpty {
                                Text("\(message.readBy.count)")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(statusColor)
                            }
                        }
                    }
                }
            }
            
            if !isCurrentUser { Spacer() }
        }
        .sheet(isPresented: $showReadReceipts) {
            ReadReceiptsView(message: message)
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
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChatView(conversation: Conversation(
            id: "preview",
            isGroup: false,
            participantIDs: ["user1", "user2"]
        ))
        .environmentObject(AuthViewModel())
    }
}
