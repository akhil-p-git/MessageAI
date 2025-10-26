import SwiftUI
import SwiftData
import FirebaseFirestore

struct NewChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @Binding var selectedConversation: Conversation?
    
    @State private var email = ""
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var recentUsers: [User] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Email Input with Arrow Button
                HStack(spacing: 12) {
                    TextField("Enter user email", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .submitLabel(.search)
                        .onSubmit {
                            Task {
                                await startChat()
                            }
                        }
                    
                    Button(action: {
                        Task {
                            await startChat()
                        }
                    }) {
                        if isSearching {
                            ProgressView()
                                .tint(.red)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title2)
                                .foregroundColor(email.isEmpty ? .gray : .red)
                        }
                    }
                    .disabled(email.isEmpty || isSearching)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
                
                // Recent Users Section
                if !recentUsers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(recentUsers) { user in
                                    RecentUserRow(user: user) {
                                        Task {
                                            await startChatWith(user: user)
                                        }
                                    }
                                    
                                    if user.id != recentUsers.last?.id {
                                        Divider()
                                            .padding(.leading, 72)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .task {
                await loadRecentUsers()
            }
        }
    }
    
    private func loadRecentUsers() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        do {
            // Get all conversations for current user
            let db = Firestore.firestore()
            let conversationsSnapshot = try await db.collection("conversations")
                .whereField("participantIDs", arrayContains: currentUser.id)
                .order(by: "lastMessageTime", descending: true)
                .limit(to: 10)
                .getDocuments()
            
            var userIDs: [String] = []
            
            // Extract other user IDs from conversations
            for doc in conversationsSnapshot.documents {
                let data = doc.data()
                if let participantIDs = data["participantIDs"] as? [String],
                   let isGroup = data["isGroup"] as? Bool,
                   !isGroup {
                    // For 1-on-1, get the other user
                    if let otherUserID = participantIDs.first(where: { $0 != currentUser.id }) {
                        if !userIDs.contains(otherUserID) {
                            userIDs.append(otherUserID)
                        }
                    }
                }
            }
            
            // Fetch user details
            var users: [User] = []
            for userID in userIDs.prefix(5) { // Limit to 5 recent users
                if let userData = try? await db.collection("users").document(userID).getDocument().data(),
                   let user = User.fromDictionary(userData) {
                    users.append(user)
                }
            }
            
            await MainActor.run {
                self.recentUsers = users
            }
        } catch {
            print("Error loading recent users: \(error)")
        }
    }
    
    private func startChatWith(user: User) async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        isSearching = true
        
        do {
            let conversation = try await ConversationService.shared.findOrCreateConversation(
                currentUserID: currentUser.id,
                otherUserID: user.id,
                modelContext: modelContext
            )
            
            await MainActor.run {
                self.selectedConversation = conversation
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isSearching = false
    }
    
    private func startChat() async {
        guard let currentUser = authViewModel.currentUser else {
            print("❌ NewChatView: No current user")
            return
        }
        
        print("\n🚀 NewChatView: Starting chat with \(email)")
        isSearching = true
        errorMessage = nil
        
        do {
            print("📧 NewChatView: Looking up user by email...")
            let otherUser = try await AuthService.shared.findUserByEmail(email: email.lowercased())
            
            guard let otherUser = otherUser else {
                print("❌ NewChatView: User not found")
                errorMessage = "User not found with email: \(email)"
                showError = true
                isSearching = false
                return
            }
            
            print("✅ NewChatView: Found user \(otherUser.displayName)")
            
            if otherUser.id == currentUser.id {
                print("❌ NewChatView: Cannot chat with yourself")
                errorMessage = "You cannot start a chat with yourself"
                showError = true
                isSearching = false
                return
            }
            
            print("🔍 NewChatView: Finding or creating conversation...")
            let conversation = try await ConversationService.shared.findOrCreateConversation(
                currentUserID: currentUser.id,
                otherUserID: otherUser.id,
                modelContext: modelContext
            )
            
            print("✅ NewChatView: Got conversation \(conversation.id)")
            
            await MainActor.run {
                print("🎯 NewChatView: Setting selected conversation...")
                self.selectedConversation = conversation
                print("🚪 NewChatView: Dismissing sheet...")
                dismiss()
                print("✅ NewChatView: Complete! Parent will handle navigation.")
            }
        } catch {
            print("❌ NewChatView: Error - \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isSearching = false
        print("🏁 NewChatView: Finished startChat()")
    }
}

// MARK: - Recent User Row

struct RecentUserRow: View {
    let user: User
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
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NewChatView(selectedConversation: .constant(nil))
        .environmentObject(AuthViewModel())
}
