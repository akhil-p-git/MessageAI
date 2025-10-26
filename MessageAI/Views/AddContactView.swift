//
//  AddContactView.swift
//  MessageAI
//
//  Add new contact by email or from recent chats
//

import SwiftUI
import FirebaseFirestore

struct AddContactView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    let onContactAdded: (User) -> Void
    
    @State private var email = ""
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var recentUsers: [User] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Email Input with Green Plus Button
                HStack(spacing: 12) {
                    TextField("Enter user email", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .submitLabel(.search)
                        .onSubmit {
                            Task {
                                await addContactByEmail()
                            }
                        }
                    
                    Button(action: {
                        Task {
                            await addContactByEmail()
                        }
                    }) {
                        if isSearching {
                            ProgressView()
                                .tint(.green)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(email.isEmpty ? .gray : .green)
                        }
                    }
                    .disabled(email.isEmpty || isSearching)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
                
                // Recent Contacts Section
                if !recentUsers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Chats")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(recentUsers.enumerated()), id: \.element.id) { index, user in
                                    RecentContactRow(user: user) {
                                        addContact(user)
                                    }
                                    
                                    if index < recentUsers.count - 1 {
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
                }
                
                Spacer()
            }
            .navigationTitle("Add Contact")
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
            let db = Firestore.firestore()
            
            // Get existing contacts to filter them out
            let userDoc = try await db.collection("users").document(currentUser.id).getDocument()
            let existingContactIDs = userDoc.data()?["contacts"] as? [String] ?? []
            
            // Get recent conversations
            let conversationsSnapshot = try await db.collection("conversations")
                .whereField("participantIDs", arrayContains: currentUser.id)
                .order(by: "lastMessageTime", descending: true)
                .limit(to: 15)
                .getDocuments()
            
            var userIDs: [String] = []
            
            for doc in conversationsSnapshot.documents {
                let data = doc.data()
                if let participantIDs = data["participantIDs"] as? [String],
                   let isGroup = data["isGroup"] as? Bool,
                   !isGroup {
                    if let otherUserID = participantIDs.first(where: { $0 != currentUser.id }) {
                        // Only show if not already a contact
                        if !userIDs.contains(otherUserID) && !existingContactIDs.contains(otherUserID) {
                            userIDs.append(otherUserID)
                        }
                    }
                }
            }
            
            var users: [User] = []
            for userID in userIDs {
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
    
    private func addContactByEmail() async {
        guard !email.isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        
        do {
            let user = try await AuthService.shared.findUserByEmail(email: email.lowercased())
            
            guard let user = user else {
                errorMessage = "User not found with email: \(email)"
                showError = true
                isSearching = false
                return
            }
            
            guard let currentUser = authViewModel.currentUser else { return }
            
            if user.id == currentUser.id {
                errorMessage = "You cannot add yourself as a contact"
                showError = true
                isSearching = false
                return
            }
            
            addContact(user)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isSearching = false
    }
    
    private func addContact(_ user: User) {
        onContactAdded(user)
        dismiss()
    }
}

// MARK: - Recent Contact Row

struct RecentContactRow: View {
    let user: User
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ProfileImageView(
                    url: user.profilePictureURL,
                    size: 56,
                    fallbackText: user.displayName
                )
                
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
                
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddContactView { _ in }
        .environmentObject(AuthViewModel())
}

