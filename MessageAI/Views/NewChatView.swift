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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Enter user email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .padding()
                
                Button(action: {
                    Task {
                        await startChat()
                    }
                }) {
                    if isSearching {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Start Chat")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || isSearching)
                .padding(.horizontal)
                
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
        }
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

#Preview {
    NewChatView(selectedConversation: .constant(nil))
        .environmentObject(AuthViewModel())
}
