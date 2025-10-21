import SwiftUI

struct ReadReceiptsView: View {
    @Environment(\.dismiss) private var dismiss
    let message: Message
    @State private var readByUsers: [User] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else if readByUsers.isEmpty {
                    Text("No read receipts yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Section {
                        ForEach(readByUsers) { user in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(user.displayName.prefix(1).uppercased())
                                            .foregroundColor(.white)
                                            .font(.headline)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.displayName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Read by \(readByUsers.count) \(readByUsers.count == 1 ? "person" : "people")")
                    }
                }
            }
            .navigationTitle("Read Receipts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await fetchReadByUsers()
            }
        }
    }
    
    private func fetchReadByUsers() async {
        isLoading = true
        
        var users: [User] = []
        
        for userID in message.readBy {
            do {
                let user = try await AuthService.shared.fetchUserDocument(userId: userID)
                users.append(user)
            } catch {
                print("Error fetching user: \(error)")
            }
        }
        
        await MainActor.run {
            self.readByUsers = users
            self.isLoading = false
        }
    }
}

#Preview {
    ReadReceiptsView(message: Message(
        id: "preview",
        conversationID: "conv1",
        senderID: "user1",
        content: "Test message",
        readBy: ["user2", "user3"]
    ))
}
