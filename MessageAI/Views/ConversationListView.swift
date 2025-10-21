import SwiftUI
import SwiftData
import FirebaseFirestore

struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @Query(sort: \Conversation.lastMessageTime, order: .reverse) private var conversations: [Conversation]
    
    @State private var showingNewChat = false
    @State private var isRefreshing = false
    @State private var showingNewGroup = false
    
    var body: some View {
        NavigationStack {
            Group {
                if conversations.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No conversations yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Start a chat to begin messaging")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Conversation List
                    List {
                        ForEach(conversations) { conversation in
                            NavigationLink(destination: ChatView(conversation: conversation)) {
                                ConversationRow(conversation: conversation)
                            }
                        }
                        .onDelete(perform: deleteConversations)
                    }
                    .refreshable {
                        await refreshConversations()
                    }
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingNewChat = true }) {
                            Label("New Chat", systemImage: "person")
                        }
                        
                        Button(action: { showingNewGroup = true }) {
                            Label("New Group", systemImage: "person.3")
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
                Task {
                    await refreshConversations()
                }
            }
        }
    }
    
    private func deleteConversations(at offsets: IndexSet) {
        for index in offsets {
            let conversation = conversations[index]
            modelContext.delete(conversation)
        }
    }
    
    private func refreshConversations() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        isRefreshing = true
        do {
            _ = try await ConversationService.shared.fetchConversations(
                userID: currentUser.id,
                modelContext: modelContext
            )
        } catch {
            print("Error fetching conversations: \(error)")
        }
        isRefreshing = false
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(conversation.name?.prefix(1).uppercased() ?? "DM")
                        .font(.headline)
                        .foregroundColor(.blue)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.name ?? "Direct Message")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(formatTime(conversation.lastMessageTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let lastMessage = conversation.lastMessage {
                    Text(lastMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            // Unread Badge
            if conversation.unreadCount > 0 {
                Text("\(conversation.unreadCount)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        
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
            formatter.dateFormat = "M/d/yy"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    ConversationListView()
        .environmentObject(AuthViewModel())
}
