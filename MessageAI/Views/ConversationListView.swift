import SwiftUI
import SwiftData
import FirebaseFirestore
import FirebaseAuth

struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var conversations: [Conversation] = []
    @State private var showingNewChat = false
    @State private var showingNewGroup = false
    @State private var isRefreshing = false
    @State private var listener: ListenerRegistration?
    @Binding var selectedConversationID: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                if conversations.isEmpty && !isRefreshing {
                    VStack(spacing: 20) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No conversations yet")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text("Start a chat to begin messaging")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(conversations) { conversation in
                            NavigationLink(value: conversation) {
                                ConversationRow(conversation: conversation)
                            }
                        }
                        .onDelete(perform: deleteConversations)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await refreshConversations()
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationDestination(for: Conversation.self) { conversation in
                ChatView(conversation: conversation)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingNewChat = true }) {
                            Label("New Chat", systemImage: "person.badge.plus")
                        }
                        
                        Button(action: { showingNewGroup = true }) {
                            Label("New Group", systemImage: "person.3.fill")
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingNewChat) {
                NewChatView()
            }
            .sheet(isPresented: $showingNewGroup) {
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
        guard let userID = authViewModel.currentUser?.id else { return }
        
        let db = Firestore.firestore()
        
        listener = db.collection("conversations")
            .whereField("participantIDs", arrayContains: userID)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else {
                    print("Error listening to conversations: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                
                var newConversations: [Conversation] = []
                
                for document in snapshot.documents {
                    var data = document.data()
                    
                    // Convert Firestore Timestamp to Date
                    if let timestamp = data["lastMessageTime"] as? Timestamp {
                        data["lastMessageTime"] = timestamp.dateValue()
                    }
                    
                    if let timestamp = data["lastReadTime"] as? Timestamp {
                        data["lastReadTime"] = timestamp.dateValue()
                    }
                    
                    if let conversation = Conversation.fromDictionary(data) {
                        newConversations.append(conversation)
                    }
                }
                
                // Sort by most recent
                newConversations.sort { $0.lastMessageTime > $1.lastMessageTime }
                
                self.conversations = newConversations
            }
    }
    
    private func deleteConversations(at offsets: IndexSet) {
        for index in offsets {
            let conversation = conversations[index]
            conversations.remove(at: index)
            
            // Delete from Firestore
            Task {
                let db = Firestore.firestore()
                try? await db.collection("conversations").document(conversation.id).delete()
            }
        }
    }
    
    private func refreshConversations() async {
        guard let userID = authViewModel.currentUser?.id else { return }
        
        isRefreshing = true
        
        do {
            _ = try await ConversationService.shared.fetchConversations(
                userID: userID,
                modelContext: modelContext
            )
        } catch {
            print("Error refreshing conversations: \(error)")
        }
        
        isRefreshing = false
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    @State private var otherUserName: String = "Loading..."
    @State private var hasUnreadMessages: Bool = false
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar with blue dot
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(avatarText)
                            .foregroundColor(.white)
                            .font(.headline)
                    )
                
                // Blue unread indicator dot
                if hasUnreadMessages {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .offset(x: 2, y: -2)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayName)
                        .font(.headline)
                        .fontWeight(hasUnreadMessages ? .bold : .semibold)
                    
                    Spacer()
                    
                    Text(formattedTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(conversation.lastMessage ?? "No messages yet")
                        .font(.subheadline)
                        .foregroundColor(hasUnreadMessages ? .primary : .secondary)
                        .fontWeight(hasUnreadMessages ? .semibold : .regular)
                        .lineLimit(2)
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
        .task {
            await fetchOtherUserName()
            checkUnreadStatus()
        }
        .onChange(of: conversation.lastMessageTime) { _, _ in
            checkUnreadStatus()
        }
    }
    
    private var displayName: String {
        if conversation.isGroup {
            return conversation.name ?? "Group Chat"
        } else {
            return otherUserName
        }
    }
    
    private var avatarText: String {
        if conversation.isGroup {
            return "G"
        } else {
            return String(otherUserName.prefix(1)).uppercased()
        }
    }
    
    private var formattedTime: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(conversation.lastMessageTime) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: conversation.lastMessageTime)
        } else if calendar.isDateInYesterday(conversation.lastMessageTime) {
            return "Yesterday"
        } else if calendar.isDate(conversation.lastMessageTime, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: conversation.lastMessageTime)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d/yy"
            return formatter.string(from: conversation.lastMessageTime)
        }
    }
    
    private func checkUnreadStatus() {
        guard let currentUserID = authViewModel.currentUser?.id else {
            hasUnreadMessages = false
            return
        }
        
        // Check if there's a new message since last read
        if let lastReadTime = conversation.lastReadTime {
            hasUnreadMessages = conversation.lastMessageTime > lastReadTime
        } else {
            // If never read, check if there are any messages
            hasUnreadMessages = conversation.lastMessage != nil
        }
    }
    
    private func fetchOtherUserName() async {
        guard !conversation.isGroup else { return }
        
        guard let currentUserID = authViewModel.currentUser?.id,
              let otherUserID = conversation.participantIDs.first(where: { $0 != currentUserID }) else {
            return
        }
        
        do {
            let user = try await AuthService.shared.fetchUserDocument(userId: otherUserID)
            await MainActor.run {
                self.otherUserName = user.displayName
            }
        } catch {
            await MainActor.run {
                self.otherUserName = "Unknown User"
            }
        }
    }
}

#Preview {
    ConversationListView(selectedConversationID: .constant(nil))
        .environmentObject(AuthViewModel())
}
