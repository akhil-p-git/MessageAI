//
//  UserProfileView.swift
//  MessageAI
//
//  View-only profile for other users
//

import SwiftUI
import SwiftData
import FirebaseFirestore

struct UserProfileView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isContact = false
    @State private var selectedConversation: Conversation?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Picture") {
                    VStack(spacing: 16) {
                        ProfileImageView(
                            url: user.profilePictureURL,
                            size: 100,
                            fallbackText: user.displayName
                        )
                        
                        // Show status if available
                        if let status = user.status, !status.isEmpty {
                            Text(status)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                }
                
                Section("Profile Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display Name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(user.displayName)
                            .font(.body)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(user.email)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(user.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await startChat()
                        }
                    }) {
                        Image(systemName: "message.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .task {
                await checkIfContact()
            }
        }
    }
    
    private func checkIfContact() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        do {
            let db = Firestore.firestore()
            let userDoc = try await db.collection("users").document(currentUser.id).getDocument()
            let contacts = userDoc.data()?["contacts"] as? [String] ?? []
            
            await MainActor.run {
                self.isContact = contacts.contains(user.id)
            }
        } catch {
            print("Error checking contact status: \(error)")
        }
    }
    
    private func toggleContact() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        do {
            let db = Firestore.firestore()
            
            if isContact {
                try await db.collection("users").document(currentUser.id).updateData([
                    "contacts": FieldValue.arrayRemove([user.id])
                ])
                await MainActor.run {
                    self.isContact = false
                }
            } else {
                try await db.collection("users").document(currentUser.id).updateData([
                    "contacts": FieldValue.arrayUnion([user.id])
                ])
                await MainActor.run {
                    self.isContact = true
                }
            }
        } catch {
            print("Error toggling contact: \(error)")
        }
    }
    
    private func startChat() async {
        print("💬 UserProfileView: Starting chat...")
        guard let currentUser = authViewModel.currentUser else {
            print("❌ No current user")
            return
        }
        
        print("   Current user: \(currentUser.id)")
        print("   Other user: \(user.id)")
        
        do {
            // Find or create conversation
            print("   Finding/creating conversation...")
            let conversation = try await ConversationService.shared.findOrCreateConversation(
                currentUserID: currentUser.id,
                otherUserID: user.id,
                modelContext: modelContext
            )
            
            print("✅ Chat created/found: \(conversation.id)")
            
            // Dismiss this view - the conversation will appear in ConversationListView
            await MainActor.run {
                print("   Dismissing UserProfileView...")
                dismiss()
            }
        } catch {
            print("❌ Error starting chat: \(error)")
            print("   Error details: \(error.localizedDescription)")
        }
    }
}

#Preview {
    UserProfileView(
        user: User(
            id: "test",
            email: "test@example.com",
            displayName: "Test User",
            status: "Hello, I'm using MessageAI!"
        )
    )
}

