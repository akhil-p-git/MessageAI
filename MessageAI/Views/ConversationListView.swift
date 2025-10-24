import SwiftUI
import FirebaseFirestore

struct ConversationListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var conversations: [Conversation] = []
    @State private var showNewChat = false
    @State private var showNewGroup = false
    @State private var listener: ListenerRegistration?
    @State private var messageListener: ListenerRegistration?
    @State private var userCache: [String: User] = [:]
    @State private var lastNotifiedMessageIDs: [String: String] = [:]  // conversationID -> lastMessageID
    @State private var selectedConversation: Conversation?
    @State private var navigateToNewChat = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if conversations.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Conversations Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Start a new chat or create a group")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(conversations) { conversation in
                            NavigationLink(destination: ChatView(conversation: conversation)) {
                                ConversationRow(conversation: conversation, userCache: userCache)
                            }
                        }
                        .onDelete(perform: deleteConversation)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showNewChat = true }) {
                            Label("New Chat", systemImage: "person.badge.plus")
                        }
                        
                        Button(action: { showNewGroup = true }) {
                            Label("New Group", systemImage: "person.3")
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showNewChat) {
                NewChatView(selectedConversation: $selectedConversation)
            }
            .sheet(isPresented: $showNewGroup) {
                NewGroupChatView()
            }
            .navigationDestination(isPresented: $navigateToNewChat) {
                if let conversation = selectedConversation {
                    ChatView(conversation: conversation)
                }
            }
            .onChange(of: selectedConversation) { oldValue, newValue in
                if newValue != nil {
                    showNewChat = false  // Dismiss the sheet
                    navigateToNewChat = true  // Navigate to the chat
                }
            }
            .onAppear {
                startListening()
                startListeningForNewMessages()
                
                // Refresh user data to get latest profile pictures
                Task {
                    await loadUserInfo()
                }
            }
            .onDisappear {
                listener?.remove()
                messageListener?.remove()
            }
        }
    }
    
    private func startListening() {
        guard let currentUser = authViewModel.currentUser else {
            print("⚠️ ConversationListView: No current user")
            return
        }
        
        let db = Firestore.firestore()
        
        print("\n👂 ConversationListView: Starting listener for user \(currentUser.id.prefix(8))...")
        
        listener = db.collection("conversations")
            .whereField("participantIDs", arrayContains: currentUser.id)
            .order(by: "lastMessageTime", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ ConversationListView: Listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("⚠️ ConversationListView: No snapshot")
                    return
                }
                
                print("\n📊 ConversationListView: Received snapshot update")
                print("   Documents: \(snapshot.documents.count)")
                print("   Document changes: \(snapshot.documentChanges.count)")
                
                // Log changes
                for change in snapshot.documentChanges {
                    let data = change.document.data()
                    let lastMsg = data["lastMessage"] as? String ?? "none"
                    let lastSender = data["lastSenderID"] as? String ?? "none"
                    
                    switch change.type {
                    case .added:
                        print("   ➕ Added: \(change.document.documentID.prefix(8))... - \(lastMsg)")
                    case .modified:
                        print("   🔄 Modified: \(change.document.documentID.prefix(8))... - \(lastMsg)")
                        print("      Sender: \(lastSender.prefix(8))...")
                    case .removed:
                        print("   ➖ Removed: \(change.document.documentID.prefix(8))...")
                    }
                }
                
                var newConversations: [Conversation] = []
                
                for document in snapshot.documents {
                    var data = document.data()
                    
                    // Convert Firestore Timestamp to Date
                    if let timestamp = data["lastMessageTime"] as? Timestamp {
                        data["lastMessageTime"] = timestamp.dateValue()
                    }
                    
                    if let conversation = Conversation.fromDictionary(data) {
                        // Filter out conversations that the current user has deleted
                        if conversation.deletedBy.contains(currentUser.id) {
                            print("   🚫 Skipping conversation \(conversation.id.prefix(8))... (deleted by current user)")
                            continue
                        }
                        
                        newConversations.append(conversation)
                        
                        // Debug first conversation
                        if newConversations.count == 1 {
                            print("\n   📋 First conversation details:")
                            print("      ID: \(conversation.id.prefix(8))...")
                            print("      Last message: \(conversation.lastMessage ?? "none")")
                            print("      Last sender: \(conversation.lastSenderID?.prefix(8) ?? "none")...")
                            print("      Unread by: \(conversation.unreadBy.count) users")
                            print("      Timestamp: \(conversation.lastMessageTime ?? Date())")
                        }
                    } else {
                        print("   ⚠️ Failed to parse conversation: \(document.documentID)")
                    }
                }
                
                print("   ✅ Parsed \(newConversations.count) conversations\n")
                
                self.conversations = newConversations
                
                // Load user info for display
                Task {
                    await self.loadUserInfo()
                }
            }
    }
    
    private func loadUserInfo() async {
        for conversation in conversations {
            for participantID in conversation.participantIDs {
                // Always refresh user data (not just if nil)
                // This ensures profile picture updates are reflected
                    if let user = try? await AuthService.shared.fetchUserDocument(userId: participantID) {
                        await MainActor.run {
                            userCache[participantID] = user
                    }
                }
            }
        }
    }
    
    private func deleteConversation(at offsets: IndexSet) {
        print("🗑️ ConversationListView: Soft deleting conversations at offsets: \(offsets)")
        
        guard let currentUser = authViewModel.currentUser else {
            print("❌ No current user")
            return
        }
        
        let db = Firestore.firestore()
        
        for index in offsets {
            guard index < conversations.count else {
                print("❌ Index \(index) out of bounds (conversations count: \(conversations.count))")
                continue
            }
            
            let conversation = conversations[index]
            print("   Soft deleting conversation: \(conversation.id.prefix(8))...")
            print("   Name: \(conversation.name ?? "1-on-1 chat")")
            print("   This will only remove it from YOUR view, not for other participants")
            
            Task {
                do {
                    // Add current user to deletedBy array (soft delete)
                    try await db.collection("conversations")
                        .document(conversation.id)
                        .updateData([
                            "deletedBy": FieldValue.arrayUnion([currentUser.id])
                        ])
                    
                    print("✅ Conversation \(conversation.id.prefix(8))... soft deleted (added to deletedBy)")
                    
                    // Remove from local array immediately for instant UI update
                    await MainActor.run {
                        if let localIndex = self.conversations.firstIndex(where: { $0.id == conversation.id }) {
                            self.conversations.remove(at: localIndex)
                            print("✅ Conversation removed from local array")
                        }
                    }
                } catch {
                    print("❌ Error deleting conversation: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func startListeningForNewMessages() {
        guard let currentUser = authViewModel.currentUser else {
            print("⚠️ ConversationListView: No current user for message listener")
            return
        }
        
        let db = Firestore.firestore()
        
        print("\n👂 ConversationListView: Starting global message listener...")
        
        // Listen to changes in conversations to detect new messages
        // This is simpler and doesn't require collectionGroup permissions
        messageListener = db.collection("conversations")
            .whereField("participantIDs", arrayContains: currentUser.id)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Message listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let changes = snapshot?.documentChanges else { return }
                
                for change in changes {
                    if change.type == .modified {
                        let data = change.document.data()
                        
                        guard let lastSenderID = data["lastSenderID"] as? String,
                              let conversationID = data["id"] as? String,
                              let lastMessageID = data["lastMessageID"] as? String else {
                            // No lastSenderID or lastMessageID means no messages yet
                            continue
                        }
                        
                        // Get lastMessage - might be nil for new conversations
                        let lastMessage = data["lastMessage"] as? String
                        
                        // Skip if there's no actual message content (new chat without messages)
                        guard let messageContent = lastMessage, !messageContent.isEmpty else {
                            print("🔕 Skipping notification - no message content (new chat)")
                            continue
                        }
                        
                        // Check if this is actually a NEW message (not just typing indicator update)
                        let previousMessageID = self.lastNotifiedMessageIDs[conversationID]
                        
                        // Check if this is a new message
                        let isNewMessage = lastMessageID != previousMessageID
                        let isFromOtherUser = lastSenderID != currentUser.id
                        
                        if isNewMessage {
                            // ALWAYS update tracked message ID when we see a new message
                            // This prevents duplicate notifications even if the user was in the chat
                            self.lastNotifiedMessageIDs[conversationID] = lastMessageID
                            
                            // Only show notification if message is from someone else
                            if isFromOtherUser {
                                // Get sender name from user cache
                                let senderName = self.userCache[lastSenderID]?.displayName ?? "Someone"
                                
                                print("🔔 New message detected (ID: \(lastMessageID.prefix(8))...): '\(messageContent)' from \(senderName)")
                                
                                // NotificationManager will check if user is in active chat and suppress if needed
                                NotificationManager.shared.showNotification(
                                    title: senderName,
                                    body: messageContent,
                                    conversationID: conversationID,
                                    senderID: lastSenderID,
                                    currentUserID: currentUser.id
                                )
                            } else {
                                print("🔕 Skipping notification - message from current user")
                            }
                        } else {
                            print("🔕 Skipping notification - same message ID (likely typing indicator update)")
                        }
                    }
                }
            }
        
        print("✅ Global message listener active\n")
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    let userCache: [String: User]
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if conversation.isGroup {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text("G")
                                .font(.title2)
                                .foregroundColor(.white)
                        )
                } else {
                    if let otherUserID = conversation.participantIDs.first(where: { $0 != authViewModel.currentUser?.id }),
                       let otherUser = userCache[otherUserID] {
                        
                        ProfileImageView(
                            url: otherUser.profilePictureURL,
                            size: 56,
                            fallbackText: otherUser.displayName
                        )
                        
                        // Show online status from cached user data (not real-time in list)
                        if otherUser.showOnlineStatus && otherUser.isOnline {
                            OnlineStatusIndicator(
                                isOnline: true,
                                size: 14
                            )
                            .offset(x: -2, y: -2)
                        }
                    } else {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 56, height: 56)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(getConversationName())
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if let lastMessageTime = conversation.lastMessageTime {
                        Text(formatTime(lastMessageTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    // Show last message
                    Text(conversation.lastMessage ?? "No messages yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if hasUnreadMessages() {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 10, height: 10)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func getConversationName() -> String {
        if conversation.isGroup {
            return conversation.name ?? "Group Chat"
        } else {
            if let otherUserID = conversation.participantIDs.first(where: { $0 != authViewModel.currentUser?.id }),
               let otherUser = userCache[otherUserID] {
                return otherUser.displayName
            }
            return "Unknown"
        }
    }
    
    private func hasUnreadMessages() -> Bool {
        guard let currentUser = authViewModel.currentUser else {
            return false
        }
        
        // Check if current user is in the unreadBy array
        return conversation.unreadBy.contains(currentUser.id)
    }
    
    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

#Preview {
    ConversationListView()
        .environmentObject(AuthViewModel())
}
