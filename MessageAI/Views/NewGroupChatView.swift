import SwiftUI
import SwiftData
import FirebaseFirestore

struct NewGroupChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var groupName = ""
    @State private var selectedUsers: Set<String> = []
    @State private var availableUsers: [User] = []
    @State private var isLoading = false
    @State private var isCreating = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView()
                } else {
                    List {
                        Section {
                            TextField("Group Name", text: $groupName)
                        }
                        
                        Section("Add Participants") {
                            ForEach(availableUsers) { user in
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
                                                .foregroundColor(.primary)
                                            
                                            Text(user.email)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if selectedUsers.contains(user.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        if !selectedUsers.isEmpty {
                            Section {
                                Text("\(selectedUsers.count) participants selected")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
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
                await loadUsers()
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
            print("❌ Error loading users: \(error)")
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
            
            let conversation = Conversation(
                id: conversationID,
                isGroup: true,
                participantIDs: participantIDs,
                name: groupName,
                lastMessage: "\(currentUser.displayName) created the group",
                lastMessageTime: Date(),
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

#Preview {
    NewGroupChatView()
        .environmentObject(AuthViewModel())
}
