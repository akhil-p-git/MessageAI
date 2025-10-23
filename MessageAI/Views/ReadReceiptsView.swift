import SwiftUI

struct ReadReceiptsView: View {
    @Environment(\.dismiss) private var dismiss
    let message: Message
    @State private var readByDetails: [(user: User, timestamp: Date)] = []
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
                } else if readByDetails.isEmpty {
                    Text("No read receipts yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Section {
                        ForEach(readByDetails, id: \.user.id) { detail in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(detail.user.displayName.prefix(1).uppercased())
                                            .foregroundColor(.white)
                                            .font(.headline)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(shortenedName(detail.user.displayName))
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    
                                    Text(formattedReadTime(detail.timestamp))
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
                        Text("Read by \(readByDetails.count) \(readByDetails.count == 1 ? "person" : "people")")
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
                await fetchReadByDetails()
            }
        }
    }
    
    private func shortenedName(_ name: String) -> String {
        if name.count > 20 {
            return String(name.prefix(17)) + "..."
        }
        return name
    }
    
    private func formattedReadTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Read at " + formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Yesterday at " + formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d 'at' h:mm a"
            return "Read " + formatter.string(from: date)
        }
    }
    
    private func fetchReadByDetails() async {
        isLoading = true
        
        var details: [(user: User, timestamp: Date)] = []
        
        // For now, we'll use the message timestamp as read time
        // To track actual read times, you'd need to store them in Firestore
        for userID in message.readBy {
            do {
                let user = try await AuthService.shared.fetchUserDocument(userId: userID)
                // Using message timestamp as placeholder - in production, store actual read times
                details.append((user: user, timestamp: message.timestamp))
            } catch {
                print("Error fetching user: \(error)")
            }
        }
        
        await MainActor.run {
            self.readByDetails = details
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
