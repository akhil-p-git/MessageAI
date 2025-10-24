import SwiftUI
import SwiftData
import FirebaseFirestore
import FirebaseStorage

struct ChatView: View {
    let conversation: Conversation
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var messageText = ""
    @State private var messages: [Message] = []
    @State private var listener: ListenerRegistration?
    @State private var isLoading = true
    @State private var isOtherUserTyping = false
    @State private var typingUserNames: [String] = []
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isUploadingImage = false
    @State private var imageCaption = ""
    @State private var showImagePreview = false
    @State private var showVoiceRecording = false
    @State private var replyingToMessage: Message?
    @State private var replyToSenderName: String?
    @State private var showSearchMessages = false
    @State private var otherUser: User?
    @State private var showBlockReport = false
    @State private var showAIPanel = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Other user info bar (for 1-on-1 chats)
            if shouldShowUserInfoBar {
                userInfoBar
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    scrollContent
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isOtherUserTyping) { _, isTyping in
                    if isTyping {
                        withAnimation {
                            proxy.scrollTo("typing-indicator", anchor: .bottom)
                        }
                    }
                }
            }
            
            if isUploadingImage {
                HStack {
                    ProgressView()
                    Text("Uploading image...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // Reply Preview
            if let replyMessage = replyingToMessage, let senderName = replyToSenderName {
                ReplyMessagePreview(
                    replyToContent: replyMessage.content,
                    replyToSenderName: senderName,
                    onCancel: {
                        replyingToMessage = nil
                        replyToSenderName = nil
                    }
                )
                .padding(.horizontal)
            }
            
            inputBar
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // AI Features Button
                    Button {
                        showAIPanel = true
                    } label: {
                        Image(systemName: "sparkles")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    toolbarMenu
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showImagePreview) {
            ImagePreviewView(
                image: $selectedImage,
                caption: $imageCaption,
                onSend: {
                    Task {
                        await sendImageMessage()
                    }
                },
                onCancel: {
                    selectedImage = nil
                    imageCaption = ""
                    showImagePreview = false
                }
            )
        }
        .sheet(isPresented: $showVoiceRecording) {
            VoiceRecordingView(
                onSend: { audioURL in
                    Task {
                        await sendVoiceMessage(audioURL: audioURL)
                    }
                    showVoiceRecording = false
                },
                onCancel: {
                    showVoiceRecording = false
                }
            )
            .presentationDetents([.height(100)])
        }
        .sheet(isPresented: $showSearchMessages) {
            SearchMessagesView(conversation: conversation)
        }
        .sheet(isPresented: $showBlockReport) {
            if let user = otherUser {
                BlockReportView(user: user)
            }
        }
        .sheet(isPresented: $showAIPanel) {
            AIFeaturesView(conversationID: conversation.id)
        }
        .onChange(of: selectedImage) { _, newImage in
            if newImage != nil {
                showImagePreview = true
            }
        }
        .onAppear {
            InAppNotificationService.shared.activeConversationID = conversation.id
            startListening()
            
            if !conversation.isGroup {
                Task {
                    await loadOtherUser()
                }
            }
            
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                await markMessagesAsRead()
            }
        }
        .onDisappear {
            if let currentUser = authViewModel.currentUser {
                TypingIndicatorService.shared.clearAllTyping(
                    conversationID: conversation.id,
                    userID: currentUser.id
                )
            }
            listener?.remove()
            InAppNotificationService.shared.activeConversationID = nil
        }
    }
    
    // MARK: - Computed Properties
    
    private var shouldShowUserInfoBar: Bool {
        !conversation.isGroup && otherUser != nil
    }
    
    private var navigationTitle: String {
        if conversation.isGroup {
            return conversation.name ?? "Group Chat"
        } else {
            return otherUser?.displayName ?? "Chat"
        }
    }
    
    // MARK: - View Components
    
    private var userInfoBar: some View {
        HStack(spacing: 8) {
            if let user = otherUser {
                OnlineStatusIndicator(isOnline: user.isOnline, size: 8)
                LastSeenView(isOnline: user.isOnline, lastSeen: user.lastSeen)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
    }
    
    @ViewBuilder
    private var scrollContent: some View {
        if isLoading {
            ProgressView()
                .padding()
        } else if messages.isEmpty {
            emptyStateView
        } else {
            messagesView
        }
    }
    
    private var emptyStateView: some View {
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
    }
    
    private var messagesView: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredMessages) { message in
                messageView(for: message)
            }
            
            if isOtherUserTyping {
                typingIndicatorView
            }
        }
        .padding()
    }
    
    private var filteredMessages: [Message] {
        messages.filter { !$0.deletedFor.contains(authViewModel.currentUser?.id ?? "") }
    }
    
    @ViewBuilder
    private func messageView(for message: Message) -> some View {
        Group {
            if message.type == .voice {
                VoiceMessageBubble(
                    message: message,
                    isCurrentUser: message.senderID == authViewModel.currentUser?.id
                )
                .contextMenu {
                    messageContextMenu(for: message)
                }
            } else if message.type == .image {
                ImageMessageBubble(
                    message: message,
                    isCurrentUser: message.senderID == authViewModel.currentUser?.id
                )
                .contextMenu {
                    messageContextMenu(for: message)
                }
            } else {
                MessageBubble(
                    message: message,
                    isCurrentUser: message.senderID == authViewModel.currentUser?.id,
                    isGroupChat: conversation.isGroup,
                    onReply: {
                        Task {
                            await handleReply(to: message)
                        }
                    }
                )
            }
        }
        .id(message.id)
    }
    
    private var typingIndicatorView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if !typingUserNames.isEmpty {
                    Text(typingText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                TypingIndicatorView()
            }
            
            Spacer()
        }
        .id("typing-indicator")
    }
    
    private var inputBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Button(action: { showImagePicker = true }) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.blue)
                }
                
                Button(action: { showVoiceRecording = true }) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.blue)
                }
            }
            .disabled(isUploadingImage)
            
            TextField("Message...", text: $messageText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .onChange(of: messageText) { oldValue, newValue in
                    let isTyping = !newValue.isEmpty
                    handleTypingChange(isTyping)
                }
                .disabled(isUploadingImage)
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(messageText.isEmpty ? .gray : .blue)
            }
            .disabled(messageText.isEmpty || isUploadingImage)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var toolbarMenu: some View {
        Menu {
            Button(action: { showSearchMessages = true }) {
                Label("Search", systemImage: "magnifyingglass")
            }
            
            if conversation.isGroup {
                NavigationLink(destination: GroupInfoView(conversation: conversation)) {
                    Label("Group Info", systemImage: "info.circle")
                }
            } else if otherUser != nil {
                Button(action: { showBlockReport = true }) {
                    Label("Block/Report", systemImage: "hand.raised")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
    
    @ViewBuilder
    private func messageContextMenu(for message: Message) -> some View {
        if message.senderID == authViewModel.currentUser?.id {
            Button(role: .destructive, action: {
                Task {
                    await deleteMessage(message, forEveryone: false)
                }
            }) {
                Label("Delete for Me", systemImage: "trash")
            }
            
            Button(role: .destructive, action: {
                Task {
                    await deleteMessage(message, forEveryone: true)
                }
            }) {
                Label("Delete for Everyone", systemImage: "trash.fill")
            }
        } else {
            Button(role: .destructive, action: {
                Task {
                    await deleteMessage(message, forEveryone: false)
                }
            }) {
                Label("Delete for Me", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var typingText: String {
        if typingUserNames.count == 1 {
            return "\(typingUserNames[0]) is typing..."
        } else if typingUserNames.count == 2 {
            return "\(typingUserNames[0]) and \(typingUserNames[1]) are typing..."
        } else if typingUserNames.count > 2 {
            return "\(typingUserNames[0]) and \(typingUserNames.count - 1) others are typing..."
        }
        return ""
    }
    
    // MARK: - Functions
    
    private func handleTypingChange(_ isTyping: Bool) {
        guard let currentUser = authViewModel.currentUser else { return }
        TypingIndicatorService.shared.setTyping(
            conversationID: conversation.id,
            userID: currentUser.id,
            isTyping: isTyping
        )
    }
    
    private func loadOtherUser() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        if let otherUserID = conversation.participantIDs.first(where: { $0 != currentUser.id }) {
            if let user = try? await AuthService.shared.fetchUserDocument(userId: otherUserID) {
                await MainActor.run {
                    self.otherUser = user
                }
            }
        }
    }
    
    private func handleReply(to message: Message) async {
        if let sender = try? await AuthService.shared.fetchUserDocument(userId: message.senderID) {
            await MainActor.run {
                self.replyingToMessage = message
                self.replyToSenderName = sender.displayName
            }
        }
    }
    
    private func deleteMessage(_ message: Message, forEveryone: Bool) async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        do {
            if forEveryone {
                try await DeleteMessageService.shared.deleteMessageForEveryone(
                    messageID: message.id,
                    conversationID: conversation.id
                )
            } else {
                try await DeleteMessageService.shared.deleteMessageForMe(
                    messageID: message.id,
                    conversationID: conversation.id,
                    userID: currentUser.id
                )
            }
        } catch {
            print("❌ Error deleting message: \(error)")
        }
    }
    
    private func startListening() {
        let db = Firestore.firestore()
        
        listener = db.collection("conversations")
            .document(conversation.id)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error: \(error)")
                    self.isLoading = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.isLoading = false
                    return
                }
                
                var newMessages: [Message] = []
                
                for document in documents {
                    var data = document.data()
                    
                    if let timestamp = data["timestamp"] as? Timestamp {
                        data["timestamp"] = timestamp.dateValue()
                    }
                    
                    if let message = Message.fromDictionary(data) {
                        newMessages.append(message)
                    }
                }
                
                self.messages = newMessages
                self.isLoading = false
                
                Task {
                    await self.markMessagesAsRead()
                }
            }
        
        listenForTypingIndicators()
    }
    
    private func listenForTypingIndicators() {
        let db = Firestore.firestore()
        
        db.collection("conversations")
            .document(conversation.id)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data(),
                      let currentUserID = self.authViewModel.currentUser?.id else {
                    return
                }
                
                let typingUsers = data["typingUsers"] as? [String] ?? []
                let otherTypingUsers = typingUsers.filter { $0 != currentUserID }
                
                self.isOtherUserTyping = !otherTypingUsers.isEmpty
                
                if !otherTypingUsers.isEmpty {
                    Task {
                        var names: [String] = []
                        for userID in otherTypingUsers {
                            if let user = try? await AuthService.shared.fetchUserDocument(userId: userID) {
                                names.append(user.displayName)
                            }
                        }
                        await MainActor.run {
                            self.typingUserNames = names
                        }
                    }
                } else {
                    self.typingUserNames = []
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
        
        TypingIndicatorService.shared.clearAllTyping(
            conversationID: conversation.id,
            userID: currentUser.id
        )
        
        let message = Message(
            id: UUID().uuidString,
            conversationID: conversation.id,
            senderID: currentUser.id,
            content: content,
            timestamp: Date(),
            status: .sent,
            type: .text,
            mediaURL: nil,
            readBy: [],
            reactions: [:],
            replyToMessageID: replyingToMessage?.id,
            replyToContent: replyingToMessage?.content,
            replyToSenderID: replyingToMessage?.senderID
        )
        
        replyingToMessage = nil
        replyToSenderName = nil
        
        Task {
            let db = Firestore.firestore()
            
            do {
                var messageData = message.toDictionary()
                messageData["timestamp"] = Timestamp(date: message.timestamp)
                messageData["status"] = "sent"
                
                try await db.collection("conversations")
                    .document(conversation.id)
                    .collection("messages")
                    .document(message.id)
                    .setData(messageData)
                
                try await db.collection("conversations")
                    .document(conversation.id)
                    .updateData([
                        "lastMessage": content,
                        "lastMessageTime": Timestamp(date: Date()),
                        "lastSenderID": currentUser.id
                    ])
            } catch {
                print("❌ Error sending message: \(error)")
            }
        }
    }
    
    private func sendImageMessage() async {
        guard let currentUser = authViewModel.currentUser,
              let image = selectedImage else {
            return
        }
        
        await MainActor.run {
            isUploadingImage = true
        }
        
        do {
            let imageURL = try await MediaService.shared.uploadImage(image, conversationID: conversation.id)
            
            let message = Message(
                id: UUID().uuidString,
                conversationID: conversation.id,
                senderID: currentUser.id,
                content: imageCaption,
                timestamp: Date(),
                status: .sent,
                type: .image,
                mediaURL: imageURL
            )
            
            let db = Firestore.firestore()
            
            var messageData = message.toDictionary()
            messageData["timestamp"] = Timestamp(date: message.timestamp)
            messageData["status"] = "sent"
            messageData["type"] = "image"
            
            try await db.collection("conversations")
                .document(conversation.id)
                .collection("messages")
                .document(message.id)
                .setData(messageData)
            
            try await db.collection("conversations")
                .document(conversation.id)
                .updateData([
                    "lastMessage": imageCaption.isEmpty ? "📷 Photo" : imageCaption,
                    "lastMessageTime": Timestamp(date: Date()),
                    "lastSenderID": currentUser.id
                ])
            
            await MainActor.run {
                selectedImage = nil
                imageCaption = ""
                showImagePreview = false
                isUploadingImage = false
            }
        } catch {
            print("❌ Error sending image: \(error)")
            await MainActor.run {
                isUploadingImage = false
            }
        }
    }
    
    private func sendVoiceMessage(audioURL: URL) async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        do {
            let data = try Data(contentsOf: audioURL)
            let filename = "\(UUID().uuidString).m4a"
            let path = "conversations/\(conversation.id)/voice/\(filename)"
            let storageRef = Storage.storage().reference().child(path)
            
            let _ = try await storageRef.putDataAsync(data)
            let downloadURL = try await storageRef.downloadURL()
            
            let message = Message(
                id: UUID().uuidString,
                conversationID: conversation.id,
                senderID: currentUser.id,
                content: "🎤 Voice message",
                timestamp: Date(),
                status: .sent,
                type: .voice,
                mediaURL: downloadURL.absoluteString
            )
            
            let db = Firestore.firestore()
            var messageData = message.toDictionary()
            messageData["timestamp"] = Timestamp(date: message.timestamp)
            messageData["status"] = "sent"
            messageData["type"] = "voice"
            
            try await db.collection("conversations")
                .document(conversation.id)
                .collection("messages")
                .document(message.id)
                .setData(messageData)
            
            try await db.collection("conversations")
                .document(conversation.id)
                .updateData([
                    "lastMessage": "🎤 Voice message",
                    "lastMessageTime": Timestamp(date: Date()),
                    "lastSenderID": currentUser.id
                ])
            
            print("✅ Voice message sent")
        } catch {
            print("❌ Error sending voice message: \(error)")
        }
    }
    
    private func markMessagesAsRead() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        let db = Firestore.firestore()
        let batch = db.batch()
        var batchCount = 0
        
        for message in messages {
            guard message.senderID != currentUser.id else { continue }
            guard !message.readBy.contains(currentUser.id) else { continue }
            
            let messageRef = db.collection("conversations")
                .document(conversation.id)
                .collection("messages")
                .document(message.id)
            
            batch.updateData(["readBy": FieldValue.arrayUnion([currentUser.id])], forDocument: messageRef)
            
            if !conversation.isGroup {
                batch.updateData(["status": "read"], forDocument: messageRef)
            }
            
            batchCount += 1
        }
        
        if batchCount > 0 {
            do {
                try await batch.commit()
            } catch {
                print("❌ Error marking as read: \(error)")
            }
        }
        
        if conversation.isGroup {
            await updateGroupMessageStatuses()
        }
    }
    
    private func updateGroupMessageStatuses() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        let db = Firestore.firestore()
        let otherParticipants = conversation.participantIDs.filter { $0 != currentUser.id }
        
        for message in messages where message.senderID == currentUser.id {
            let allRead = otherParticipants.allSatisfy { message.readBy.contains($0) }
            
            let newStatus: String
            if allRead {
                newStatus = "read"
            } else if !message.readBy.isEmpty {
                newStatus = "delivered"
            } else {
                continue
            }
            
            if message.statusRaw != newStatus {
                try? await db.collection("conversations")
                    .document(conversation.id)
                    .collection("messages")
                    .document(message.id)
                    .updateData(["status": newStatus])
            }
        }
    }
}

// MARK: - MessageBubble

struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    let isGroupChat: Bool
    let onReply: () -> Void
    @State private var showReadReceipts = false
    @State private var showReactionPicker = false
    @State private var showForwardSheet = false
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if message.deletedForEveryone {
                    Text("This message was deleted")
                        .italic()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .foregroundColor(.secondary)
                        .cornerRadius(18)
                } else {
                    if let replyContent = message.replyToContent,
                       let replySenderID = message.replyToSenderID {
                        ReplyBubbleView(
                            replyToContent: replyContent,
                            replyToSenderName: replySenderID,
                            isCurrentUser: isCurrentUser
                        )
                        .padding(.horizontal, 4)
                    }
                    
                    Text(message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                        .foregroundColor(isCurrentUser ? .white : .primary)
                        .cornerRadius(18)
                        .contextMenu {
                            Button(action: onReply) {
                                Label("Reply", systemImage: "arrowshape.turn.up.left")
                            }
                            
                            Button(action: {
                                showForwardSheet = true
                            }) {
                                Label("Forward", systemImage: "arrowshape.turn.up.right")
                            }
                            
                            Button(action: {
                                showReactionPicker = true
                            }) {
                                Label("Add Reaction", systemImage: "face.smiling")
                            }
                            
                            Button(action: {
                                UIPasteboard.general.string = message.content
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            
                            if isCurrentUser && isGroupChat && !message.readBy.isEmpty {
                                Button(action: {
                                    showReadReceipts = true
                                }) {
                                    Label("Read Receipts", systemImage: "eye")
                                }
                            }
                        }
                        .onLongPressGesture {
                            showReactionPicker = true
                        }
                    
                    MessageReactionsView(message: message, isCurrentUser: isCurrentUser)
                    
                    HStack(spacing: 4) {
                        Text(formattedTime)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if isCurrentUser {
                            HStack(spacing: 2) {
                                Image(systemName: statusIcon)
                                    .font(.caption2)
                                    .foregroundColor(statusColor)
                                
                                if isGroupChat && !message.readBy.isEmpty {
                                    Button(action: {
                                        showReadReceipts = true
                                    }) {
                                        Text("\(message.readBy.count)")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(statusColor)
                                    }
                                }
                            }
                        }
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
        .sheet(isPresented: $showReadReceipts) {
            ReadReceiptsView(message: message)
        }
        .sheet(isPresented: $showForwardSheet) {
            ForwardMessageView(message: message)
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
    NavigationStack {
        ChatView(conversation: Conversation(
            id: "preview",
            isGroup: false,
            participantIDs: ["user1", "user2"]
        ))
        .environmentObject(AuthViewModel())
    }
}
