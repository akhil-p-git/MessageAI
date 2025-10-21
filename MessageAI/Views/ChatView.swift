import SwiftUI
import SwiftData
import FirebaseFirestore

struct ChatView: View {
    let conversation: Conversation
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @Query private var allMessages: [Message]
    @State private var typingUsers: [String] = []
    @State private var typingListener: ListenerRegistration?
    @State private var typingTimer: Timer?
    @State private var messageText = ""
    @State private var listener: ListenerRegistration?
    @State private var showGroupInfo = false
    
    private var messages: [Message] {
        allMessages.filter { $0.conversationID == conversation.id }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            messagesView
            inputBar
        }
        .navigationTitle(conversationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if conversation.isGroup {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showGroupInfo = true }) {
                        Image(systemName: "info.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showGroupInfo) {
            GroupInfoView(conversation: conversation)
        }
        .onAppear {
            setupRealtimeListener()
        }
        .onDisappear {
            listener?.remove()
            typingListener?.remove()
            typingTimer?.invalidate()
            
            // Clear typing status when leaving
            if let currentUser = authViewModel.currentUser {
                Task {
                    await PresenceService.shared.setTyping(
                        conversationID: conversation.id,
                        userID: currentUser.id,
                        isTyping: false
                    )
                }
            }
        }
    }

    private var conversationTitle: String {
        conversation.isGroup ? (conversation.name ?? "Group Chat") : "Chat"
    }
    
    private var typingText: String? {
        let otherTypingUsers = typingUsers.filter { $0 != authViewModel.currentUser?.id }
        guard !otherTypingUsers.isEmpty else { return nil }
        
        if otherTypingUsers.count == 1 {
            return "typing..."
        } else {
            return "\(otherTypingUsers.count) people typing..."
        }
    }

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(
                            message: message,
                            isFromCurrentUser: message.senderID == authViewModel.currentUser?.id,
                            conversation: conversation
                        )
                        .id(message.id)
                    }
                    
                    // Typing Indicator
                    if let typingText = typingText {
                        HStack {
                            Text(typingText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: typingText) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Message...", text: $messageText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onChange(of: messageText) { _, newValue in
                    handleTyping(newValue)
                }
                .onSubmit {
                    sendMessage()
                }
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(messageText.isEmpty ? .gray : .blue)
            }
            .disabled(messageText.isEmpty)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let currentUser = authViewModel.currentUser else {
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
            status: .sending,
            type: .text
        )
        
        // Save to SwiftData
        modelContext.insert(message)
        
        // Save to Firestore
        Task {
            do {
                let db = Firestore.firestore()
                try await db.collection("conversations")
                    .document(conversation.id)
                    .collection("messages")
                    .document(message.id)
                    .setData(message.toDictionary())
                
                // Update conversation's last message
                try await ConversationService.shared.updateLastMessage(
                    conversationID: conversation.id,
                    message: content
                )
                
                // Update message status
                message.status = .sent
                try modelContext.save()
            } catch {
                print("Error sending message: \(error)")
            }
        }
    }
    
    private func setupRealtimeListener() {
        let db = Firestore.firestore()
        
        listener = db.collection("conversations")
            .document(conversation.id)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else {
                    print("Error fetching messages: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                
                for change in snapshot.documentChanges {
                    if change.type == .added {
                        if let message = Message.fromDictionary(change.document.data()) {
                            // Check if message already exists
                            let existingMessage = allMessages.first { $0.id == message.id }
                            if existingMessage == nil {
                                modelContext.insert(message)
                                try? modelContext.save()
                            }
                        }
                    }
                }
            }
            typingListener = PresenceService.shared.listenToTyping(conversationID: conversation.id) { userIDs in
                typingUsers = userIDs
            }
    }
    
    private func handleTyping(_ text: String) {
        guard let currentUser = authViewModel.currentUser else { return }
        
        // Cancel existing timer
        typingTimer?.invalidate()
        
        if !text.isEmpty {
            // User is typing
            Task {
                await PresenceService.shared.setTyping(
                    conversationID: conversation.id,
                    userID: currentUser.id,
                    isTyping: true
                )
            }
            
            // Set timer to clear typing status after 3 seconds
            typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                Task {
                    await PresenceService.shared.setTyping(
                        conversationID: conversation.id,
                        userID: currentUser.id,
                        isTyping: false
                    )
                }
            }
        } else {
            // User cleared text
            Task {
                await PresenceService.shared.setTyping(
                    conversationID: conversation.id,
                    userID: currentUser.id,
                    isTyping: false
                )
            }
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    let conversation: Conversation
    
    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer() }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Show sender name in group chats
                if conversation.isGroup && !isFromCurrentUser {
                    Text(message.senderID)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(message.content)
                    .padding(12)
                    .background(isFromCurrentUser ? Color.blue : Color(uiColor: .systemGray5))
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(16)
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isFromCurrentUser { Spacer() }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

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
