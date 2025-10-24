import SwiftUI
import FirebaseFirestore

struct ConversationListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var conversations: [Conversation] = []
    @State private var showNewChat = false
    @State private var showNewGroup = false
    @State private var listener: ListenerRegistration?
    @State private var userCache: [String: User] = [:]
    
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
            }
            .onDisappear {
                listener?.remove()
            }
        }
    }
    
    private func startListening() {
        guard let currentUser = authViewModel.currentUser else { return }
        
        let db = Firestore.firestore()
        
        listener = db.collection("conversations")
            .whereField("participantIDs", arrayContains: currentUser.id)
            .order(by: "lastMessageTime", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching conversations: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                
                var newConversations: [Conversation] = []
                
                for document in documents {
                    var data = document.data()
                    
                    if let timestamp = data["lastMessageTime"] as? Timestamp {
                        data["lastMessageTime"] = timestamp.dateValue()
                    }
                    
                    if let conversation = Conversation.fromDictionary(data) {
                        newConversations.append(conversation)
                    }
                }
                
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
                if userCache[participantID] == nil {
                    if let user = try? await AuthService.shared.fetchUserDocument(userId: participantID) {
                        await MainActor.run {
                            userCache[participantID] = user
                        }
                    }
                }
            }
        }
    }
    
    private func deleteConversation(at offsets: IndexSet) {
        // TODO: Implement conversation deletion
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
                        
                        OnlineStatusIndicator(isOnline: otherUser.isOnline, size: 14)
                            .offset(x: -2, y: -2)
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
