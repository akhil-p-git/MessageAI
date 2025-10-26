//
//  ContactsView.swift
//  MessageAI
//
//  Contacts management view
//

import SwiftUI
import SwiftData
import FirebaseFirestore

struct ContactsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var contacts: [User] = []
    @State private var isLoading = false
    @State private var showAddContact = false
    @State private var selectedConversation: Conversation?
    
    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if contacts.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("No Contacts Yet")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Add contacts to quickly start conversations")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                showAddContact = true
                            }) {
                                Text("Add Contact")
                                    .font(.body)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                } else {
                    Section {
                        ForEach(contacts) { contact in
                            ContactRowWithActions(
                                user: contact,
                                onMessage: {
                                    Task {
                                        await startChat(with: contact)
                                    }
                                },
                                selectedConversation: $selectedConversation,
                                showChat: $showChat
                            )
                        }
                        .onDelete(perform: deleteContacts)
                    }
                }
            }
            .navigationTitle("Contacts")
            .navigationBarItems(
                leading: contacts.isEmpty ? nil : EditButton(),
                trailing: Button(action: { showAddContact = true }) {
                    Image(systemName: "plus")
                }
            )
            .sheet(isPresented: $showAddContact) {
                AddContactView { newContact in
                    addContact(newContact)
                }
            }
            .task {
                await loadContacts()
            }
            .refreshable {
                await loadContacts()
            }
        }
    }
    
    private func loadContacts() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        isLoading = true
        
        do {
            let db = Firestore.firestore()
            let userDoc = try await db.collection("users").document(currentUser.id).getDocument()
            
            guard let contactIDs = userDoc.data()?["contacts"] as? [String] else {
                await MainActor.run {
                    self.contacts = []
                    self.isLoading = false
                }
                return
            }
            
            var loadedContacts: [User] = []
            for contactID in contactIDs {
                if let userData = try? await db.collection("users").document(contactID).getDocument().data(),
                   let user = User.fromDictionary(userData) {
                    loadedContacts.append(user)
                }
            }
            
            await MainActor.run {
                self.contacts = loadedContacts.sorted { $0.displayName < $1.displayName }
                self.isLoading = false
            }
        } catch {
            print("Error loading contacts: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func addContact(_ user: User) {
        guard let currentUser = authViewModel.currentUser else { return }
        
        Task {
            do {
                let db = Firestore.firestore()
                
                try await db.collection("users").document(currentUser.id).updateData([
                    "contacts": FieldValue.arrayUnion([user.id])
                ])
                
                await loadContacts()
            } catch {
                print("Error adding contact: \(error)")
            }
        }
    }
    
    private func deleteContacts(at offsets: IndexSet) {
        guard let currentUser = authViewModel.currentUser else { return }
        
        let contactsToRemove = offsets.map { contacts[$0].id }
        
        Task {
            do {
                let db = Firestore.firestore()
                
                try await db.collection("users").document(currentUser.id).updateData([
                    "contacts": FieldValue.arrayRemove(contactsToRemove)
                ])
                
                await MainActor.run {
                    contacts.remove(atOffsets: offsets)
                }
            } catch {
                print("Error deleting contact: \(error)")
            }
        }
    }
    
    private func startChat(with user: User) async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        do {
            let conversation = try await ConversationService.shared.findOrCreateConversation(
                currentUserID: currentUser.id,
                otherUserID: user.id,
                modelContext: modelContext
            )
            
            // Navigation will happen automatically through ConversationListView
            print("✅ Chat ready: \(conversation.id)")
        } catch {
            print("Error starting chat: \(error)")
        }
    }
}

// MARK: - Contact Row With Actions

struct ContactRowWithActions: View {
    let user: User
    let onMessage: () -> Void
    @State private var showProfile = false
    
    var body: some View {
        Button(action: {
            showProfile = true
        }) {
            HStack(spacing: 12) {
                ProfileImageView(
                    url: user.profilePictureURL,
                    size: 50,
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
                
                Button(action: onMessage) {
                    Image(systemName: "message.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showProfile) {
            UserProfileView(user: user)
        }
    }
}

#Preview {
    ContactsView()
        .environmentObject(AuthViewModel())
}
