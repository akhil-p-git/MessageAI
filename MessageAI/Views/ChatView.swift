import SwiftUI
import SwiftData
import FirebaseFirestore
import PhotosUI

struct ChatView: View {
    let conversation: Conversation
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @Query private var allMessages: [Message]
    @State private var messageText = ""
    @State private var listener: ListenerRegistration?
    @State private var showGroupInfo = false
    @State private var typingUsers: [String] = []
    @State private var typingListener: ListenerRegistration?
    @State private var typingTimer: Timer?
    @State private var readReceiptListener: ListenerRegistration?
    @State private var selectedImage: PhotosPickerItem?
    @State private var isUploadingImage = false
    
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
            markMessagesAsRead()
        }
        .onDisappear {
            listener?.remove()
            typingListener?.remove()
            typingTimer?.invalidate()
            
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
            PhotosPicker(selection: $selectedImage, matching: .images) {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
            .onChange(of: selectedImage) { _, newValue in
                if newValue != nil {
                    uploadSelectedImage()
                }
            }
            
            TextField("Message...", text: $messageText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onChange(of: messageText) { _, newValue in
                    handleTyping(newValue)
                }
                .onSubmit {
                    sendMessage()
                }
            
            if isUploadingImage {
                ProgressView()
                    .progressViewStyle(.circular)
            } else {
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(messageText.isEmpty ? .gray : .blue)
                }
                .disabled(messageText.isEmpty)
            }
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
        
        modelContext.insert(message)
        
        Task {
            do {
                let db = Firestore.firestore()
                try await db.collection("conversations")
                    .document(conversation.id)
                    .collection("messages")
                    .document(message.id)
                    .setData(message.toDictionary())
                
                try await ConversationService.shared.updateLastMessage(
                    conversationID: conversation.id,
                    message: content
                )
                
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
        
        typingTimer?.invalidate()
        
        if !text.isEmpty {
            Task {
                await PresenceService.shared.setTyping(
                    conversationID: conversation.id,
                    userID: currentUser.id,
                    isTyping: true
                )
            }
            
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
            Task {
                await PresenceService.shared.setTyping(
                    conversationID: conversation.id,
                    userID: currentUser.id,
                    isTyping: false
                )
            }
        }
    }
    
    private func markMessagesAsRead() {
        guard let currentUser = authViewModel.currentUser else { return }
        
        let unreadMessages = messages.filter { message in
            message.senderID != currentUser.id &&
            !message.readBy.contains(currentUser.id)
        }
        
        for message in unreadMessages {
            if !message.readBy.contains(currentUser.id) {
                message.readBy.append(currentUser.id)
            }
            
            Task {
                let db = Firestore.firestore()
                try? await db.collection("conversations")
                    .document(conversation.id)
                    .collection("messages")
                    .document(message.id)
                    .updateData([
                        "readBy": FieldValue.arrayUnion([currentUser.id])
                    ])
            }
        }
    }
    
    private func uploadSelectedImage() {
        guard let selectedImage = selectedImage,
              let currentUser = authViewModel.currentUser else {
            return
        }
        
        isUploadingImage = true
        
        Task {
            do {
                guard let imageData = try await selectedImage.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: imageData) else {
                    isUploadingImage = false
                    return
                }
                
                let imageURL = try await MediaService.shared.uploadImage(uiImage, conversationID: conversation.id)
                
                let message = Message(
                    id: UUID().uuidString,
                    conversationID: conversation.id,
                    senderID: currentUser.id,
                    content: "[Image]",
                    timestamp: Date(),
                    status: .sending,
                    type: .image,
                    mediaURL: imageURL
                )
                
                modelContext.insert(message)
                
                let db = Firestore.firestore()
                try await db.collection("conversations")
                    .document(conversation.id)
                    .collection("messages")
                    .document(message.id)
                    .setData(message.toDictionary())
                
                try await ConversationService.shared.updateLastMessage(
                    conversationID: conversation.id,
                    message: "[Image]"
                )
                
                message.status = .sent
                try modelContext.save()
                
                self.selectedImage = nil
            } catch {
                print("Error uploading image: \(error)")
            }
            
            isUploadingImage = false
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
                if conversation.isGroup && !isFromCurrentUser {
                    Text(message.senderID)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if message.type == .image, let mediaURL = message.mediaURL {
                    AsyncImage(url: URL(string: mediaURL)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 200, height: 200)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: 250, maxHeight: 300)
                                .cornerRadius(12)
                                .clipped()
                        case .failure:
                            Image(systemName: "photo")
                                .frame(width: 200, height: 200)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Text(message.content)
                        .padding(12)
                        .background(isFromCurrentUser ? Color.blue : Color(uiColor: .systemGray5))
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                        .cornerRadius(16)
                }
                
                HStack(spacing: 4) {
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if isFromCurrentUser {
                        readReceiptIcon
                    }
                }
            }
            
            if !isFromCurrentUser { Spacer() }
        }
    }
    
    private var readReceiptIcon: some View {
        Group {
            if message.readBy.count > 1 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
            } else if message.status == .delivered {
                Image(systemName: "checkmark.circle")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else if message.status == .sent {
                Image(systemName: "checkmark")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
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
