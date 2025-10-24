import SwiftUI
import FirebaseFirestore

struct ForwardMessageView: View {
    let message: Message
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var conversations: [Conversation] = []
    @State private var selectedConversations: Set<String> = []
    @State private var isLoading = true
    @State private var isForwarding = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView()
                } else if conversations.isEmpty {
                    Text("No conversations to forward to")
                        .foregroundColor(.secondary)
                } else {
                    List(conversations) { conversation in
                        Button(action: {
                            toggleSelection(conversation.id)
                        }) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Text(conversation.isGroup ? "G" : (conversation.name?.prefix(1) ?? "C"))
                                            .foregroundColor(.white)
                                            .font(.headline)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(conversation.name ?? (conversation.isGroup ? "Group" : "Chat"))
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    if conversation.isGroup {
                                        Text("\(conversation.participantIDs.count) members")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if selectedConversations.contains(conversation.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Forward Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Forward") {
                        Task {
                            await forwardMessage()
                        }
                    }
                    .disabled(selectedConversations.isEmpty || isForwarding)
                }
            }
            .task {
                await loadConversations()
            }
        }
    }
    
    private func toggleSelection(_ id: String) {
        if selectedConversations.contains(id) {
            selectedConversations.remove(id)
        } else {
            selectedConversations.insert(id)
        }
    }
    
    private func loadConversations() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        isLoading = true
        
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("conversations")
                .whereField("participantIDs", arrayContains: currentUser.id)
                .order(by: "lastMessageTime", descending: true)
                .getDocuments()
            
            var loadedConversations: [Conversation] = []
            
            for document in snapshot.documents {
                var data = document.data()
                
                if let timestamp = data["lastMessageTime"] as? Timestamp {
                    data["lastMessageTime"] = timestamp.dateValue()
                }
                
                if let conversation = Conversation.fromDictionary(data),
                   conversation.id != message.conversationID {
                    loadedConversations.append(conversation)
                }
            }
            
            await MainActor.run {
                self.conversations = loadedConversations
                self.isLoading = false
            }
        } catch {
            print("❌ Error loading conversations: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func forwardMessage() async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        isForwarding = true
        
        let db = Firestore.firestore()
        
        for conversationID in selectedConversations {
            let forwardedMessage = Message(
                id: UUID().uuidString,
                conversationID: conversationID,
                senderID: currentUser.id,
                content: message.content,
                timestamp: Date(),
                status: .sent,
                type: message.type,
                mediaURL: message.mediaURL
            )
            
            do {
                var messageData = forwardedMessage.toDictionary()
                messageData["timestamp"] = Timestamp(date: forwardedMessage.timestamp)
                messageData["status"] = "sent"
                
                try await db.collection("conversations")
                    .document(conversationID)
                    .collection("messages")
                    .document(forwardedMessage.id)
                    .setData(messageData)
                
                // Get conversation to find other participants
                let conversationDoc = try await db.collection("conversations")
                    .document(conversationID)
                    .getDocument()
                
                let participantIDs = conversationDoc.data()?["participantIDs"] as? [String] ?? []
                let otherParticipants = participantIDs.filter { $0 != currentUser.id }
                
                try await db.collection("conversations")
                    .document(conversationID)
                    .updateData([
                        "lastMessage": message.content,
                        "lastMessageTime": Timestamp(date: Date()),
                        "lastSenderID": currentUser.id,
                        "lastMessageID": forwardedMessage.id,
                        "unreadBy": otherParticipants
                    ])
            } catch {
                print("❌ Error forwarding message: \(error)")
            }
        }
        
        await MainActor.run {
            isForwarding = false
            dismiss()
        }
    }
}
