import SwiftUI

struct GroupInfoView: View {
    @Environment(\.dismiss) private var dismiss
    let conversation: Conversation
    
    var body: some View {
        NavigationStack {
            List {
                Section("Group Info") {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(conversation.name ?? "Group Chat")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Participants (\(conversation.participantIDs.count))") {
                    ForEach(conversation.participantIDs, id: \.self) { participantID in
                        HStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(participantID.prefix(1).uppercased())
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                )
                            
                            Text(participantID)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Group Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    GroupInfoView(conversation: Conversation(
        id: "preview",
        isGroup: true,
        name: "Team Chat",
        participantIDs: ["user1", "user2", "user3"]
    ))
}
