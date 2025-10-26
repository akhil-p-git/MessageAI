import SwiftUI

struct BlockReportView: View {
    let user: User
    let conversationID: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var showReportSheet = false
    @State private var reportReason = ""
    @State private var isBlocked = false
    @State private var showSuccessAlert = false
    @State private var successMessage = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(role: .destructive, action: {
                        Task {
                            await toggleBlock()
                        }
                    }) {
                        Label(isBlocked ? "Unblock User" : "Block User", systemImage: isBlocked ? "checkmark.circle" : "hand.raised")
                    }
                    
                    Button(role: .destructive, action: {
                        showReportSheet = true
                    }) {
                        Label("Report User", systemImage: "exclamationmark.triangle")
                    }
                } header: {
                    Text("Actions")
                } footer: {
                    if isBlocked {
                        Text("You won't receive messages from this user.")
                    } else {
                        Text("Blocked users cannot send you messages.")
                    }
                }
            }
            .navigationTitle("Manage User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showReportSheet) {
                ReportUserSheet(
                    user: user,
                    onReport: { reason in
                        Task {
                            await reportUser(reason: reason)
                        }
                    }
                )
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text(successMessage)
            }
            .task {
                await checkBlockStatus()
            }
        }
    }
    
    private func checkBlockStatus() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        do {
            isBlocked = try await BlockUserService.shared.isBlocked(
                blockerID: currentUser.id,
                blockedID: user.id
            )
        } catch {
            print("❌ Error checking block status: \(error)")
        }
    }
    
    private func toggleBlock() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        do {
            if isBlocked {
                try await BlockUserService.shared.unblockUser(
                    blockerID: currentUser.id,
                    blockedID: user.id
                )
                successMessage = "User unblocked successfully"
            } else {
                try await BlockUserService.shared.blockUser(
                    blockerID: currentUser.id,
                    blockedID: user.id,
                    conversationID: conversationID
                )
                successMessage = "User blocked, removed from contacts, and conversation deleted"
            }
            
            isBlocked.toggle()
            showSuccessAlert = true
        } catch {
            print("❌ Error toggling block: \(error)")
        }
    }
    
    private func reportUser(reason: String) async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        do {
            try await BlockUserService.shared.reportUser(
                reporterID: currentUser.id,
                reportedID: user.id,
                reason: reason
            )
            
            successMessage = "User reported successfully. Thank you for keeping our community safe."
            showSuccessAlert = true
        } catch {
            print("❌ Error reporting user: \(error)")
        }
    }
}

struct ReportUserSheet: View {
    let user: User
    let onReport: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedReason = "Spam"
    @State private var customReason = ""
    
    private let reportReasons = ["Spam", "Harassment", "Inappropriate Content", "Scam", "Other"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Reason") {
                    Picker("Select reason", selection: $selectedReason) {
                        ForEach(reportReasons, id: \.self) { reason in
                            Text(reason).tag(reason)
                        }
                    }
                    
                    if selectedReason == "Other" {
                        TextField("Describe the issue", text: $customReason, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                
                Section {
                    Button("Submit Report") {
                        let reason = selectedReason == "Other" ? customReason : selectedReason
                        onReport(reason)
                        dismiss()
                    }
                    .disabled(selectedReason == "Other" && customReason.isEmpty)
                }
            }
            .navigationTitle("Report \(user.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    BlockReportView(
        user: User(
            id: "user1",
            email: "test@example.com",
            displayName: "Test User"
        ),
        conversationID: "test-conv"
    )
    .environmentObject(AuthViewModel())
}
