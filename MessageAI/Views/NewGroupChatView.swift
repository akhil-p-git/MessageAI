import SwiftUI
import FirebaseFirestore

struct NewGroupChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var groupName = ""
    @State private var searchText = ""
    @State private var availableUsers: [User] = []
    @State private var selectedUsers: Set<String> = []
    @State private var isLoading = false
    @State private var isCreating = false
    @State private var createdConversation: Conversation?
    @State private var navigateToChat = false
    
    var filteredUsers: [User] {
        if searchText.isEmpty {
            return availableUsers
        }
        return availableUsers.filter { user in
            user.displayName.localizedCaseInsensitiveContains(searchText) ||
            user.email.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Group Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Group Name")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    TextField("Enter group name", text: $groupName)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                }
                .padding(.vertical)
                
                Divider()
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search users", text: $searchText)
                        .autocapitalization(.none)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                // Selected Users Count
                if !selectedUsers.isEmpty {
                    HStack {
                        Text("\(selectedUsers.count) \(selectedUsers.count == 1 ? "member" : "members") selected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                
                // User List
                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    List(filteredUsers) { user in
                        Button(action: {
                            toggleUserSelection(user.id)
                        }) {
                            HStack(spacing: 12) {
                                ProfileImageView(
                                    url: user.profilePictureURL,
                                    size: 44,
                                    fallbackText: user.displayName
                                )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.displayName)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedUsers.contains(user.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await createGroup()
                        }
                    }
                    .disabled(groupName.isEmpty || selectedUsers.count < 1 || isCreating)
                }
            }
            .task {
                await loadUsers()
            }
            .navigationDestination(isPresented: $navigateToChat) {
                if let conversation = createdConversation {
                    ChatView(conversation: conversation)
                }
            }
        }
    }
    
    private func toggleUserSelection(_ userID: String) {
        if selectedUsers.contains(userID) {
            selectedUsers.remove(userID)
        } else {
            selectedUsers.insert(userID)
        }
    }
    
    private func loadUsers() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        isLoading = true
        
        do {
            let users = try await AuthService.shared.fetchAllUsers()
            await MainActor.run {
                self.availableUsers = users.filter { $0.id != currentUser.id }
                self.isLoading = false
            }
        } catch {
            print("Error loading users: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func createGroup() async {
        guard let currentUser = authViewModel.currentUser,
              !groupName.isEmpty,
              !selectedUsers.isEmpty else {
            return
        }
        
        isCreating = true
        
        do {
            let conversationID = UUID().uuidString
            var participantIDs = Array(selectedUsers)
            participantIDs.append(currentUser.id)
            
            let conversation = Conversation(
                id: conversationID,
                isGroup: true,
                name: groupName,
                participantIDs: participantIDs,
                lastMessage: "\(currentUser.displayName) created the group",
                lastMessageTime: Date(),
                unreadCount: 0
            )
            
            let db = Firestore.firestore()
            
            var conversationData = conversation.toDictionary()
            conversationData["lastMessageTime"] = Timestamp(date: Date())
            conversationData["creatorID"] = currentUser.id
            
            try await db.collection("conversations")
                .document(conversationID)
                .setData(conversationData)
            
            // Send system message (only other participants will see it as notification)
            let systemMessage = Message(
                id: UUID().uuidString,
                conversationID: conversationID,
                senderID: currentUser.id,
                content: "\(currentUser.displayName) created \"\(groupName)\"",
                timestamp: Date(),
                status: .sent,
                type: .text
            )
            
            var messageData = systemMessage.toDictionary()
            messageData["timestamp"] = Timestamp(date: systemMessage.timestamp)
            messageData["status"] = "sent"
            messageData["isSystemMessage"] = true
            
            try await db.collection("conversations")
                .document(conversationID)
                .collection("messages")
                .document(systemMessage.id)
                .setData(messageData)
            
            await MainActor.run {
                self.createdConversation = conversation
                self.isCreating = false
                self.navigateToChat = true
                dismiss()
            }
            
            print("✅ Group created successfully")
        } catch {
            print("❌ Error creating group: \(error)")
            await MainActor.run {
                self.isCreating = false
            }
        }
    }
}

#Preview {
    NewGroupChatView()
        .environmentObject(AuthViewModel())
}
