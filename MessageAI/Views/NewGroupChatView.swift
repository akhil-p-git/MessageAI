import SwiftUI
import SwiftData

struct NewGroupChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var groupName = ""
    @State private var participantEmails: [String] = ["", "", ""]
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Group Info") {
                    TextField("Group Name", text: $groupName)
                }
                
                Section("Add Participants (minimum 2)") {
                    ForEach(0..<participantEmails.count, id: \.self) { index in
                        HStack {
                            TextField("Email \(index + 1)", text: $participantEmails[index])
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                            
                            if index >= 3 {
                                Button(action: { participantEmails.remove(at: index) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    Button(action: { participantEmails.append("") }) {
                        Label("Add Participant", systemImage: "plus.circle.fill")
                    }
                }
                
                Section {
                    Button(action: createGroup) {
                        if isCreating {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Create Group")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isValidForm || isCreating)
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
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }
    
    private var isValidForm: Bool {
        !groupName.isEmpty &&
        participantEmails.filter { !$0.isEmpty }.count >= 2
    }
    
    private func createGroup() {
        guard let currentUser = authViewModel.currentUser else { return }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                // Filter out empty emails
                let validEmails = participantEmails.filter { !$0.isEmpty }
                
                // Find all users by email
                var participantIDs = [currentUser.id]
                
                for email in validEmails {
                    do {
                        let user = try await AuthService.shared.findUserByEmail(email.lowercased())
                        if !participantIDs.contains(user.id) {
                            participantIDs.append(user.id)
                        }
                    } catch {
                        errorMessage = "Could not find user: \(email)"
                        showError = true
                        isCreating = false
                        return
                    }
                }
                
                // Create group
                _ = try await GroupChatService.shared.createGroupChat(
                    name: groupName,
                    participantIDs: participantIDs,
                    creatorID: currentUser.id,
                    modelContext: modelContext
                )
                
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            
            isCreating = false
        }
    }
}

#Preview {
    NewGroupChatView()
        .environmentObject(AuthViewModel())
}//
//  NewGroupChatView.swift
//  MessageAI
//
//  Created by Akhil Pinnani on 10/20/25.
//

