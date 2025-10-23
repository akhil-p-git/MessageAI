import SwiftUI
import SwiftData
import FirebaseFirestore

struct NewChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var email = ""
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var createdConversation: Conversation?
    @State private var navigateToChat = false
    
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
            .navigationDestination(isPresented: $navigateToChat) {
                if let conversation = createdConversation {
                    ChatView(conversation: conversation)
                }
            }
        }
    }
    
    private func startChat() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        isSearching = true
        errorMessage = nil
        
        do {
            let otherUser = try await AuthService.shared.findUserByEmail(email: email.lowercased())
            
            guard let otherUser = otherUser else {
                errorMessage = "User not found with email: \(email)"
                showError = true
                isSearching = false
                return
            }
            
            if otherUser.id == currentUser.id {
                errorMessage = "You cannot start a chat with yourself"
                showError = true
                isSearching = false
                return
            }
            
            let conversation = try await ConversationService.shared.findOrCreateConversation(
                currentUserID: currentUser.id,
                otherUserID: otherUser.id,
                modelContext: modelContext
            )
            
            await MainActor.run {
                self.createdConversation = conversation
                self.navigateToChat = true
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isSearching = false
    }
}

#Preview {
    NewChatView()
        .environmentObject(AuthViewModel())
}
