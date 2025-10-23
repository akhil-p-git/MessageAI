import SwiftUI
import FirebaseFirestore

struct SearchMessagesView: View {
    let conversation: Conversation
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var searchText = ""
    @State private var searchResults: [Message] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if searchResults.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text(isSearching ? "Searching..." : "No results found")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List(searchResults) { message in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(message.senderID == authViewModel.currentUser?.id ? "You" : "Other")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(formatDate(message.timestamp))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(highlightedText(message.content))
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search Messages")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search in conversation")
            .onChange(of: searchText) { _, newValue in
                if !newValue.isEmpty {
                    Task {
                        await searchMessages(query: newValue)
                    }
                } else {
                    searchResults = []
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func searchMessages(query: String) async {
        isSearching = true
        
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("conversations")
                .document(conversation.id)
                .collection("messages")
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            var results: [Message] = []
            
            for document in snapshot.documents {
                var data = document.data()
                
                if let timestamp = data["timestamp"] as? Timestamp {
                    data["timestamp"] = timestamp.dateValue()
                }
                
                if let message = Message.fromDictionary(data),
                   message.content.localizedCaseInsensitiveContains(query) {
                    results.append(message)
                }
            }
            
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
            }
        } catch {
            print("❌ Error searching messages: \(error)")
            await MainActor.run {
                self.isSearching = false
            }
        }
    }
    
    private func highlightedText(_ text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        if let range = attributedString.range(of: searchText, options: .caseInsensitive) {
            attributedString[range].backgroundColor = .yellow.opacity(0.3)
        }
        
        return attributedString
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    SearchMessagesView(
        conversation: Conversation(
            id: "preview",
            isGroup: false,
            participantIDs: ["user1", "user2"]
        )
    )
    .environmentObject(AuthViewModel())
}
