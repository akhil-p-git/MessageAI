import SwiftUI
import SwiftData

struct NewChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    
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
                
                Button(action: startChat) {
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
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }
    
    private func startChat() {
        guard let currentUser = authViewModel.currentUser else { return }
        
        isSearching = true
        errorMessage = nil
        
        Task {
            do {
                let otherUser = try await AuthService.shared.findUserByEmail(email.lowercased())
                
                if otherUser.id == currentUser.id {
                    errorMessage = "You cannot start a chat with yourself"
                    showError = true
                    isSearching = false
                    return
                }
                
                _ = try await ConversationService.shared.findOrCreateConversation(
                    currentUserID: currentUser.id,
                    otherUserID: otherUser.id,
                    modelContext: modelContext
                )
                
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            
            isSearching = false
        }
    }
}

#Preview {
    NewChatView()
        .environmentObject(AuthViewModel())
}//
//  NewChatView.swift
//  MessageAI
//
//  Created by Akhil Pinnani on 10/20/25.
//

