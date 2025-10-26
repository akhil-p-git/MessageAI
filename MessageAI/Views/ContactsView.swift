//
//  ContactsView.swift
//  MessageAI
//
//  Contacts management view
//

import SwiftUI
import FirebaseFirestore

struct ContactsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var contacts: [User] = []
    @State private var isLoading = false
    @State private var isEditMode = false
    @State private var showAddContact = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if contacts.isEmpty {
                    // Empty State
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
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            showAddContact = true
                        }) {
                            Label("Add Contact", systemImage: "plus.circle.fill")
                                .font(.body)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Contacts List
                    List {
                        ForEach(contacts) { contact in
                            ContactRow(user: contact)
                        }
                        .onDelete(perform: isEditMode ? deleteContacts : nil)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !contacts.isEmpty {
                        Button(isEditMode ? "Done" : "Edit") {
                            withAnimation {
                                isEditMode.toggle()
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddContact = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
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
            
            // Fetch contact details
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
                
                // Add to user's contacts array in Firestore
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
}

// MARK: - Contact Row

struct ContactRow: View {
    let user: User
    
    var body: some View {
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
                
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ContactsView()
        .environmentObject(AuthViewModel())
}

