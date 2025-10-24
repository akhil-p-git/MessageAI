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
    @State private var typingListener: ListenerRegistration?
    @State private var presenceListener: ListenerRegistration?
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
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var syncService = MessageSyncService.shared
    @State private var showReadReceipts = false
    @State private var selectedMessageForReceipts: Message?
    
    var body: some View {
        VStack(spacing: 0) {
            // Offline/Syncing Banner
            OfflineBanner()
                .padding(.horizontal)
                .padding(.top, 4)
            
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
                    // Network status indicator
                    if !networkMonitor.isConnected {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                    
                    // AI Features Button
                    Button {
                        showAIPanel = true
                    } label: {
                        Image(systemName: "sparkles")
                            .foregroundStyle(
                                networkMonitor.isConnected ?
                                LinearGradient(
                                    colors: [.blue, .purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [.gray, .gray],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .disabled(!networkMonitor.isConnected)
                    .opacity(networkMonitor.isConnected ? 1.0 : 0.5)
                    
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
        .sheet(isPresented: $showReadReceipts) {
            if let message = selectedMessageForReceipts {
                ReadReceiptsView(message: message)
            }
        }
        .onChange(of: selectedImage) { _, newImage in
            if newImage != nil {
                showImagePreview = true
            }
        }
        .onAppear {
            // Track that we're viewing this chat (for notifications)
            NotificationManager.shared.enterChat(conversation.id)
            
            InAppNotificationService.shared.activeConversationID = conversation.id
            startListening()
            setupPresenceListener()
            
            if !conversation.isGroup {
                Task {
                    await loadOtherUser()
                }
            }
            
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                await markMessagesAsRead()
            }
            
            #if DEBUG
            // Quick Firebase connectivity test
            Task {
                let db = Firestore.firestore()
                do {
                    try await db.collection("_test").document("test").setData(["test": true, "timestamp": Date()])
                    print("✅ FIREBASE WRITE: SUCCESS - Firebase connection is working!")
                } catch {
                    print("❌ FIREBASE WRITE FAILED: \(error.localizedDescription)")
                    print("❌ Full error: \(error)")
                }
            }
            #endif
        }
        .onDisappear {
            print("👋 ChatView: Cleaning up listeners...")
            
            // Track that we left this chat (for notifications)
            NotificationManager.shared.exitChat()
            
            if let currentUser = authViewModel.currentUser {
                TypingIndicatorService.shared.clearAllTyping(
                    conversationID: conversation.id,
                    userID: currentUser.id
                )
            }
            
            listener?.remove()
            typingListener?.remove()
            presenceListener?.remove()
            
            InAppNotificationService.shared.activeConversationID = nil
            
            print("✅ ChatView: Listeners removed\n")
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
                // Only show online status if user allows it
                if user.showOnlineStatus {
                    OnlineStatusIndicator(
                        isOnline: user.isOnline,
                        size: 8
                    )
                }
                // Only show last seen if user allows it
                if user.showOnlineStatus {
                    LastSeenView(isOnline: user.isOnline, lastSeen: user.lastSeen)
                }
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
            userName: currentUser.displayName,
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
        print("\n👂 ChatView: Setting up message listener for conversation \(conversation.id.prefix(8))...")
        
        let db = Firestore.firestore()
        
        // Remove old listener if exists
        listener?.remove()
        
        listener = db.collection("conversations")
            .document(conversation.id)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ ChatView: Message listener error: \(error)")
                    self.isLoading = false
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("⚠️ ChatView: No snapshot")
                    self.isLoading = false
                    return
                }
                
                print("📨 ChatView: Received snapshot with \(snapshot.documents.count) messages")
                print("   Document changes: \(snapshot.documentChanges.count)")
                
                // Handle document changes to update existing messages efficiently
                for change in snapshot.documentChanges {
                    var data = change.document.data()
                    
                    // Convert Firestore Timestamp to Date
                    if let timestamp = data["timestamp"] as? Timestamp {
                        data["timestamp"] = timestamp.dateValue()
                    }
                    
                    guard let updatedMessage = Message.fromDictionary(data) else {
                        print("   ⚠️ Failed to parse message from change")
                        continue
                    }
                    
                    switch change.type {
                    case .added:
                        // Check if message already exists (to avoid duplicates)
                        if !self.messages.contains(where: { $0.id == updatedMessage.id }) {
                            self.messages.append(updatedMessage)
                            print("   ➕ Added message: '\(updatedMessage.content)' from \(updatedMessage.senderID.prefix(8))...")
                            
                            // Save to SwiftData
                            self.modelContext.insert(updatedMessage)
                            try? self.modelContext.save()
                            
                            // Trigger notification for messages from others
                            if let currentUser = self.authViewModel.currentUser,
                               updatedMessage.senderID != currentUser.id {
                                let senderName = data["senderName"] as? String ?? "Someone"
                                
                                NotificationManager.shared.showNotification(
                                    title: senderName,
                                    body: updatedMessage.content,
                                    conversationID: self.conversation.id,
                                    senderID: updatedMessage.senderID,
                                    currentUserID: currentUser.id
                                )
                            }
                        }
                        
                    case .modified:
                        // Find and update the existing message
                        if let index = self.messages.firstIndex(where: { $0.id == updatedMessage.id }) {
                            // Update the message properties while keeping the same object reference
                            let existingMessage = self.messages[index]
                            existingMessage.content = updatedMessage.content
                            existingMessage.statusRaw = updatedMessage.statusRaw
                            existingMessage.readBy = updatedMessage.readBy
                            existingMessage.reactions = updatedMessage.reactions
                            existingMessage.mediaURL = updatedMessage.mediaURL
                            
                            print("   ✏️ Modified message: '\(updatedMessage.content)' - readBy: \(updatedMessage.readBy.count) users")
                            
                            // Save to SwiftData
                            try? self.modelContext.save()
                            
                            // Force UI update
                            self.messages[index] = existingMessage
                        }
                        
                    case .removed:
                        self.messages.removeAll(where: { $0.id == updatedMessage.id })
                        print("   🗑️ Removed message: \(updatedMessage.id)")
                    }
                }
                
                // Sort messages by timestamp
                self.messages.sort { $0.timestamp < $1.timestamp }
                
                self.isLoading = false
                
                print("   ✅ Total messages in chat: \(self.messages.count)\n")
                
                // Mark messages as read after a short delay
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    await self.markMessagesAsRead()
                }
            }
        
        print("✅ ChatView: Message listener active")
        
        listenForTypingIndicators()
    }
    
    private func listenForTypingIndicators() {
        print("👂 ChatView: Setting up typing indicator listener...")
        
        let db = Firestore.firestore()
        
        // Remove old listener if exists
        typingListener?.remove()
        
        typingListener = db.collection("conversations")
            .document(conversation.id)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ ChatView: Typing listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = snapshot?.data(),
                      let currentUserID = self.authViewModel.currentUser?.id else {
                    return
                }
                
                let typingUsers = data["typingUsers"] as? [String] ?? []
                let otherTypingUsers = typingUsers.filter { $0 != currentUserID }
                
                let wasTyping = self.isOtherUserTyping
                self.isOtherUserTyping = !otherTypingUsers.isEmpty
                
                if self.isOtherUserTyping != wasTyping {
                    print("⌨️  ChatView: Typing indicator changed - \(otherTypingUsers.count) users typing")
                }
                
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
        
        print("✅ ChatView: Typing indicator listener active\n")
    }
    
    private func setupPresenceListener() {
        // Only for 1-on-1 chats
        guard !conversation.isGroup,
              let currentUser = authViewModel.currentUser,
              let otherUserID = conversation.participantIDs.first(where: { $0 != currentUser.id }) else {
            return
        }
        
        print("👂 ChatView: Setting up presence listener for user: \(otherUserID.prefix(8))...")
        
        let db = Firestore.firestore()
        
        // Remove old listener if exists
        presenceListener?.remove()
        
        presenceListener = db.collection("users")
            .document(otherUserID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ ChatView: Presence listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = snapshot?.data() else {
                    return
                }
                
                let isOnline = data["isOnline"] as? Bool ?? false
                let showOnlineStatus = data["showOnlineStatus"] as? Bool ?? true
                
                print("🔄 ChatView: Presence updated - isOnline=\(isOnline), showStatus=\(showOnlineStatus)")
                
                // Update the otherUser object
                if let otherUser = self.otherUser {
                    otherUser.isOnline = isOnline
                    otherUser.showOnlineStatus = showOnlineStatus
                    
                    // Force UI update by creating a new reference
                    self.otherUser = otherUser
                }
            }
        
        print("✅ ChatView: Presence listener active\n")
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
        
        // Determine initial status based on connectivity
        let initialStatus: MessageStatus = networkMonitor.isConnected ? .sending : .pending
        
        let message = Message(
            id: UUID().uuidString,
            conversationID: conversation.id,
            senderID: currentUser.id,
            content: content,
            timestamp: Date(),
            status: initialStatus,
            type: .text,
            mediaURL: nil,
            readBy: [],
            reactions: [:],
            replyToMessageID: replyingToMessage?.id,
            replyToContent: replyingToMessage?.content,
            replyToSenderID: replyingToMessage?.senderID,
            needsSync: true
        )
        
        replyingToMessage = nil
        replyToSenderName = nil
        
        // Use offline-first approach: save locally first, then sync
        Task {
            do {
                try await syncService.queueMessage(
                    message,
                    conversationID: conversation.id,
                    currentUserID: currentUser.id,
                    modelContext: modelContext
                )
                
                // If online, also update Firebase directly
                if networkMonitor.isConnected {
                    let db = Firestore.firestore()
                    
                    print("\n📤 Uploading message to Firebase...")
                    print("   Message ID: \(message.id)")
                    print("   Content: \(content)")
                    print("   Conversation ID: \(conversation.id)")
                    
                    var messageData = message.toDictionary()
                    messageData["timestamp"] = Timestamp(date: message.timestamp)
                    messageData["status"] = "sent"
                    messageData["senderName"] = currentUser.displayName
                    
                    try await db.collection("conversations")
                        .document(conversation.id)
                        .collection("messages")
                        .document(message.id)
                        .setData(messageData)
                    
                    print("   ✅ Message document created")
                    
                    // Get all participants except the sender
                    let otherParticipants = conversation.participantIDs.filter { $0 != currentUser.id }
                    
                    print("   📝 Updating conversation metadata...")
                    print("      Conversation ID: \(conversation.id)")
                    print("      Participants: \(conversation.participantIDs)")
                    print("      Other participants (unreadBy): \(otherParticipants)")
                    
                    // Use setData with merge to create document if it doesn't exist
                    do {
                        try await db.collection("conversations")
                            .document(conversation.id)
                            .setData([
                                "lastMessage": content,
                                "lastMessageTime": Timestamp(date: Date()),
                                "lastSenderID": currentUser.id,
                                "lastMessageID": message.id,
                                "unreadBy": otherParticipants
                            ], merge: true)
                        
                        print("   ✅ Conversation metadata updated successfully!")
                        print("      lastMessage: \(content)")
                        print("      lastSenderID: \(currentUser.id)")
                        print("      unreadBy: \(otherParticipants)\n")
                    } catch {
                        print("   ❌ CRITICAL ERROR updating conversation metadata!")
                        print("      Error: \(error.localizedDescription)")
                        if let nsError = error as NSError? {
                            print("      Domain: \(nsError.domain)")
                            print("      Code: \(nsError.code)")
                            print("      UserInfo: \(nsError.userInfo)")
                        }
                        // Don't throw - message was created successfully
                    }
                } else {
                    print("   ⚠️ Offline - message queued for sync\n")
                }
            } catch {
                print("❌ Error sending message: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("   Error domain: \(nsError.domain)")
                    print("   Error code: \(nsError.code)")
                    print("   Error info: \(nsError.userInfo)")
                }
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
            
            print("\n📤 Uploading image message to Firebase...")
            print("   Message ID: \(message.id)")
            print("   Caption: \(imageCaption.isEmpty ? "📷 Photo" : imageCaption)")
            
            try await db.collection("conversations")
                .document(conversation.id)
                .collection("messages")
                .document(message.id)
                .setData(messageData)
            
            print("   ✅ Image message document created")
            
            // Get all participants except the sender
            let otherParticipants = conversation.participantIDs.filter { $0 != currentUser.id }
            
            print("   📝 Updating conversation metadata for image...")
            print("      Conversation ID: \(conversation.id)")
            
            // Use setData with merge to create document if it doesn't exist
            do {
                try await db.collection("conversations")
                    .document(conversation.id)
                    .setData([
                        "lastMessage": imageCaption.isEmpty ? "📷 Photo" : imageCaption,
                        "lastMessageTime": Timestamp(date: Date()),
                        "lastSenderID": currentUser.id,
                        "lastMessageID": message.id,
                        "unreadBy": otherParticipants
                    ], merge: true)
                
                print("   ✅ Conversation metadata updated for image!\n")
            } catch {
                print("   ❌ CRITICAL ERROR updating conversation for image!")
                print("      Error: \(error.localizedDescription)")
                // Don't throw - message was created successfully
            }
            
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
            
            print("\n📤 Uploading voice message to Firebase...")
            print("   Message ID: \(message.id)")
            
            try await db.collection("conversations")
                .document(conversation.id)
                .collection("messages")
                .document(message.id)
                .setData(messageData)
            
            print("   ✅ Voice message document created")
            
            // Get all participants except the sender
            let otherParticipants = conversation.participantIDs.filter { $0 != currentUser.id }
            
            print("   📝 Updating conversation metadata for voice...")
            print("      Conversation ID: \(conversation.id)")
            
            // Use setData with merge to create document if it doesn't exist
            do {
                try await db.collection("conversations")
                    .document(conversation.id)
                    .setData([
                        "lastMessage": "🎤 Voice message",
                        "lastMessageTime": Timestamp(date: Date()),
                        "lastSenderID": currentUser.id,
                        "lastMessageID": message.id,
                        "unreadBy": otherParticipants
                    ], merge: true)
                
                print("   ✅ Conversation metadata updated for voice!")
                print("✅ Voice message sent\n")
            } catch {
                print("   ❌ CRITICAL ERROR updating conversation for voice!")
                print("      Error: \(error.localizedDescription)")
                // Don't throw - message was created successfully
            }
        } catch {
            print("❌ Error sending voice message: \(error)")
        }
    }
    
    private func markMessagesAsRead() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        let db = Firestore.firestore()
        let batch = db.batch()
        var batchCount = 0
        
        // Track messages we're updating
        var updatedMessageIDs: [String] = []
        
        for message in messages {
            // Skip messages sent by current user
            guard message.senderID != currentUser.id else { continue }
            
            // Skip messages already read by current user
            guard !message.readBy.contains(currentUser.id) else { continue }
            
            let messageRef = db.collection("conversations")
                .document(conversation.id)
                .collection("messages")
                .document(message.id)
            
            // Add current user to readBy array
            batch.updateData([
                "readBy": FieldValue.arrayUnion([currentUser.id])
            ], forDocument: messageRef)
            
            // For 1-on-1 chats, update status to "read"
            if !conversation.isGroup {
                batch.updateData([
                    "status": "read"
                ], forDocument: messageRef)
            }
            
            updatedMessageIDs.append(message.id)
            batchCount += 1
            
            // Firestore batch limit is 500
            if batchCount >= 500 {
                break
            }
        }
        
        if batchCount > 0 {
            do {
                try await batch.commit()
                print("✅ Marked \(batchCount) messages as read")
                
                // Update local SwiftData immediately for instant UI update
                for messageID in updatedMessageIDs {
                    if let index = messages.firstIndex(where: { $0.id == messageID }) {
                        if !messages[index].readBy.contains(currentUser.id) {
                            messages[index].readBy.append(currentUser.id)
                            
                            // Update status for 1-on-1 chats
                            if !conversation.isGroup {
                                messages[index].statusRaw = "read"
                            }
                            
                            try? modelContext.save()
                        }
                    }
                }
                
                // ✅ Remove current user from conversation's unreadBy array
                try await db.collection("conversations")
                    .document(conversation.id)
                    .updateData([
                        "unreadBy": FieldValue.arrayRemove([currentUser.id])
                    ])
                
                print("✅ Cleared unread indicator for conversation")
                
            } catch {
                print("❌ Error marking messages as read: \(error.localizedDescription)")
            }
        }
        
        // For group chats, update message statuses based on readBy array
        if conversation.isGroup {
            await updateGroupMessageStatuses()
        }
    }
    
    private func updateGroupMessageStatuses() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        let db = Firestore.firestore()
        let otherParticipants = conversation.participantIDs.filter { $0 != currentUser.id }
        
        for message in messages where message.senderID == currentUser.id {
            // Check if all other participants have read the message
            let allRead = otherParticipants.allSatisfy { message.readBy.contains($0) }
            
            let newStatus: String
            if allRead {
                newStatus = "read"
            } else if !message.readBy.isEmpty {
                newStatus = "delivered"
            } else {
                continue // No change needed
            }
            
            // Only update if status changed
            if message.statusRaw != newStatus {
                do {
                    try await db.collection("conversations")
                        .document(conversation.id)
                        .collection("messages")
                        .document(message.id)
                        .updateData(["status": newStatus])
                    
                    // Update local message
                    message.statusRaw = newStatus
                    try? modelContext.save()
                    
                    print("✅ Updated message \(message.id) status to \(newStatus)")
                } catch {
                    print("❌ Error updating status: \(error.localizedDescription)")
                }
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
                            MessageStatusIndicator(status: message.status)
                            
                            if isGroupChat && !message.readBy.isEmpty && message.status == .read {
                                Button(action: {
                                    showReadReceipts = true
                                }) {
                                    Text("\(message.readBy.count)")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.blue)
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
        case .pending:
            return "clock"
        case .sending:
            return "arrow.up.circle"
        case .sent:
            return "checkmark"
        case .delivered:
            return "checkmark.circle"
        case .read:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.circle"
        }
    }
    
    private var statusColor: Color {
        switch message.status {
        case .pending:
            return .orange
        case .sending:
            return .blue
        case .sent:
            return .gray
        case .delivered:
            return .gray
        case .read:
            return .blue
        case .failed:
            return .red
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
