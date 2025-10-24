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
                NewChatView()
            }
            .sheet(isPresented: $showNewGroup) {
                NewGroupChatView()
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
        // TODO: Implement conversation deletion
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
                              let lastMessage = data["lastMessage"] as? String,
                              let lastMessageID = data["lastMessageID"] as? String else {
                            continue
                        }
                        
                        // Check if this is actually a NEW message (not just typing indicator update)
                        let previousMessageID = self.lastNotifiedMessageIDs[conversationID]
                        
                        // Only show notification if:
                        // 1. Message ID is different (new message, not typing update)
                        // 2. Message is from someone else
                        // 3. Not in that specific chat (handled by NotificationManager)
                        if lastMessageID != previousMessageID && lastSenderID != currentUser.id {
                            // Update tracked message ID
                            self.lastNotifiedMessageIDs[conversationID] = lastMessageID
                            
                            // Get sender name from user cache
                            let senderName = self.userCache[lastSenderID]?.displayName ?? "Someone"
                            
                            print("🔔 New message detected (ID: \(lastMessageID.prefix(8))...): '\(lastMessage)' from \(senderName)")
                            
                            NotificationManager.shared.showNotification(
                                title: senderName,
                                body: lastMessage,
                                conversationID: conversationID,
                                senderID: lastSenderID,
                                currentUserID: currentUser.id
                            )
                        } else if lastMessageID == previousMessageID {
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
    
    @State private var typingUsers: [String] = []
    @State private var typingListener: ListenerRegistration?
    @State private var presenceListener: ListenerRegistration?
    @State private var otherUserOnline: Bool = false
    @State private var otherUserShowStatus: Bool = true
    
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
                        
                        // Show online status using real-time state
                        if otherUserShowStatus && otherUserOnline {
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
                    // Show typing indicator if someone is typing
                    if !typingUsers.isEmpty {
                        HStack(spacing: 4) {
                            Text("typing")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .italic()
                            
                            // Animated dots
                            HStack(spacing: 2) {
                                ForEach(0..<3) { _ in
                                    Circle()
                                        .fill(Color.secondary)
                                        .frame(width: 4, height: 4)
                                }
                            }
                        }
                    } else {
                        // Show last message
                        Text(conversation.lastMessage ?? "No messages yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
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
        .onAppear {
            startListeningForTyping()
            startListeningForPresence()
        }
        .onDisappear {
            typingListener?.remove()
            presenceListener?.remove()
        }
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
    
    private func startListeningForTyping() {
        guard let currentUser = authViewModel.currentUser else { return }
        
        let db = Firestore.firestore()
        
        typingListener = db.collection("conversations")
            .document(conversation.id)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data() else { return }
                
                let typingUserIDs = data["typingUsers"] as? [String] ?? []
                
                // Filter out current user
                let otherTypingUsers = typingUserIDs.filter { $0 != currentUser.id }
                
                self.typingUsers = otherTypingUsers
                
                if !otherTypingUsers.isEmpty {
                    print("⌨️  ConversationRow: \(otherTypingUsers.count) users typing in \(conversation.id.prefix(8))...")
                }
            }
    }
    
    private func startListeningForPresence() {
        guard let currentUser = authViewModel.currentUser,
              !conversation.isGroup,
              let otherUserID = conversation.participantIDs.first(where: { $0 != currentUser.id }) else {
            return
        }
        
        let db = Firestore.firestore()
        
        presenceListener = db.collection("users")
            .document(otherUserID)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data() else {
                    return
                }
                
                let isOnline = data["isOnline"] as? Bool ?? false
                let showOnlineStatus = data["showOnlineStatus"] as? Bool ?? true
                
                // Update state variables for real-time UI updates
                self.otherUserOnline = isOnline
                self.otherUserShowStatus = showOnlineStatus
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
