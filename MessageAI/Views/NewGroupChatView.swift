import SwiftUI
import SwiftData
import FirebaseFirestore

struct NewGroupChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var groupName = ""
    @State private var selectedUsers: Set<String> = []
    @State private var recentUsers: [User] = []
    @State private var isLoading = false
    @State private var isCreating = false
    
    // Placeholder contacts for future functionality
    private let placeholderContacts = [
        ("A", "a@example.com"),
        ("B", "b@example.com"),
        ("C", "c@example.com"),
        ("D", "d@example.com")
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Group Name Input
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Group Name", text: $groupName)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .padding()
                
                // Content
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Recent Chats Section
                            if !recentUsers.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Recent Chats")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal)
                                    
                                    VStack(spacing: 0) {
                                        ForEach(Array(recentUsers.prefix(3).enumerated()), id: \.element.id) { index, user in
                                            GroupParticipantRow(
                                                user: user,
                                                isSelected: selectedUsers.contains(user.id),
                                                onTap: {
                                                    toggleUserSelection(user.id)
                                                }
                                            )
                                            
                                            if index < min(2, recentUsers.count - 1) {
                                                Divider()
                                                    .padding(.leading, 84)
                                            }
                                        }
                                    }
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                }
                            }
                            
                            // Contacts Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Contacts")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 0) {
                                    ForEach(Array(placeholderContacts.enumerated()), id: \.offset) { index, contact in
                                        PlaceholderContactRow(
                                            name: contact.0,
                                            email: contact.1
                                        )
                                        
                                        if index < placeholderContacts.count - 1 {
                                            Divider()
                                                .padding(.leading, 84)
                                        }
                                    }
                                }
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            
                            // Selection Count
                            if !selectedUsers.isEmpty {
                                Text("\(selectedUsers.count) participant\(selectedUsers.count == 1 ? "" : "s") selected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            await createGroup()
                        }
                    }
                    .disabled(groupName.isEmpty || selectedUsers.count < 2 || isCreating)
                }
            }
            .task {
                await loadRecentUsers()
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
    
    private func loadRecentUsers() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        isLoading = true
        
        do {
            // Get recent conversations for current user
            let db = Firestore.firestore()
            let conversationsSnapshot = try await db.collection("conversations")
                .whereField("participantIDs", arrayContains: currentUser.id)
                .order(by: "lastMessageTime", descending: true)
                .limit(to: 10)
                .getDocuments()
            
            var userIDs: [String] = []
            
            // Extract other user IDs from 1-on-1 conversations
            for doc in conversationsSnapshot.documents {
                let data = doc.data()
                if let participantIDs = data["participantIDs"] as? [String],
                   let isGroup = data["isGroup"] as? Bool,
                   !isGroup {
                    if let otherUserID = participantIDs.first(where: { $0 != currentUser.id }) {
                        if !userIDs.contains(otherUserID) {
                            userIDs.append(otherUserID)
                        }
                    }
                }
            }
            
            // Fetch user details
            var users: [User] = []
            for userID in userIDs.prefix(3) { // Limit to 3 recent users
                if let userData = try? await db.collection("users").document(userID).getDocument().data(),
                   let user = User.fromDictionary(userData) {
                    users.append(user)
                }
            }
            
            await MainActor.run {
                self.recentUsers = users
                self.isLoading = false
            }
        } catch {
            print("Error loading recent users: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func createGroup() async {
        guard let currentUser = authViewModel.currentUser,
              !groupName.isEmpty,
              selectedUsers.count >= 2 else {
            return
        }
        
        isCreating = true
        
        do {
            let conversationID = UUID().uuidString
            var participantIDs = Array(selectedUsers)
            participantIDs.append(currentUser.id)
            
            // Mark as unread for all participants except the creator
            let otherParticipants = participantIDs.filter { $0 != currentUser.id }
            
            // Create system message first
            let systemMessageID = UUID().uuidString
            let systemMessageContent = "\(currentUser.displayName) added you to \"\(groupName)\""
            
            let systemMessage = Message(
                id: systemMessageID,
                conversationID: conversationID,
                senderID: currentUser.id,
                content: systemMessageContent,
                timestamp: Date(),
                status: .sent,
                type: .text
            )
            
            let conversation = Conversation(
                id: conversationID,
                isGroup: true,
                participantIDs: participantIDs,
                name: groupName,
                lastMessage: systemMessageContent,
                lastMessageTime: Date(),
                lastSenderID: currentUser.id,
                lastMessageID: systemMessageID,  // Set the message ID
                unreadBy: otherParticipants,
                creatorID: currentUser.id
            )
            
            let db = Firestore.firestore()
            
            var conversationData = conversation.toDictionary()
            conversationData["lastMessageTime"] = Timestamp(date: Date())
            conversationData["creatorID"] = currentUser.id
            
            try await db.collection("conversations")
                .document(conversationID)
                .setData(conversationData)
            
            // Send system message
            var messageData = systemMessage.toDictionary()
            messageData["timestamp"] = Timestamp(date: systemMessage.timestamp)
            messageData["status"] = "sent"
            messageData["isSystemMessage"] = true
            messageData["senderName"] = currentUser.displayName
            
            try await db.collection("conversations")
                .document(conversationID)
                .collection("messages")
                .document(systemMessage.id)
                .setData(messageData)
            
            await MainActor.run {
                isCreating = false
                dismiss()
            }
        } catch {
            print("❌ Error creating group: \(error)")
            await MainActor.run {
                isCreating = false
            }
        }
    }
}

// MARK: - Group Participant Row

struct GroupParticipantRow: View {
    let user: User
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile Picture
                ProfileImageView(
                    url: user.profilePictureURL,
                    size: 56,
                    fallbackText: user.displayName
                )
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Placeholder Contact Row

struct PlaceholderContactRow: View {
    let name: String
    let email: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Placeholder Profile Picture
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 56, height: 56)
                .overlay(
                    Text(name)
                        .font(.title2)
                        .foregroundColor(.gray)
                )
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                
                Text(email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .opacity(0.6)
    }
}

#Preview {
    NewGroupChatView()
        .environmentObject(AuthViewModel())
}


