//
//  GroupInfoView.swift
//  MessageAI
//
//  Group chat information and management
//

import SwiftUI
import FirebaseFirestore

struct GroupInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    let conversation: Conversation
    
    @State private var participants: [User] = []
    @State private var isLoading = true
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isUploadingImage = false
    
    var groupInitial: String {
        if let name = conversation.name, let first = name.first {
            return String(first).uppercased()
        }
        return "G"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Group Info") {
                    VStack(spacing: 16) {
                        // Group Profile Picture
                        if let selectedImage = selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                        } else if let url = conversation.groupPictureURL, !url.isEmpty {
                            AsyncImage(url: URL(string: url)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                case .failure, .empty:
                                    groupIconFallback
                                @unknown default:
                                    groupIconFallback
                                }
                            }
                        } else {
                            groupIconFallback
                        }
                        
                        // Change Photo Button
                        Button(action: { showImagePicker = true }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Change Photo")
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(conversation.name ?? "Group Chat")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Participants (\(participants.count))") {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        ForEach(participants) { participant in
                            HStack(spacing: 12) {
                                ProfileImageView(
                                    url: participant.profilePictureURL,
                                    size: 44,
                                    fallbackText: participant.displayName
                                )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(participant.displayName)
                                        .font(.body)
                                    
                                    Text(participant.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // Remove button (only if you're the creator and it's not yourself)
                                if conversation.creatorID == authViewModel.currentUser?.id,
                                   participant.id != authViewModel.currentUser?.id {
                                    Button(action: {
                                        removeParticipant(participant)
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Group Info")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView(selectedImage: $selectedImage)
            }
            .task {
                await loadParticipants()
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                if newValue != nil {
                    Task {
                        await uploadGroupPicture()
                    }
                }
            }
        }
    }
    
    private var groupIconFallback: some View {
        Circle()
            .fill(Color.blue.opacity(0.2))
            .frame(width: 100, height: 100)
            .overlay(
                Text(groupInitial)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.blue)
            )
    }
    
    private func loadParticipants() async {
        do {
            let db = Firestore.firestore()
            var loadedParticipants: [User] = []
            
            for participantID in conversation.participantIDs {
                if let userData = try? await db.collection("users").document(participantID).getDocument().data(),
                   let user = User.fromDictionary(userData) {
                    loadedParticipants.append(user)
                }
            }
            
            await MainActor.run {
                self.participants = loadedParticipants.sorted { $0.displayName < $1.displayName }
                self.isLoading = false
            }
        } catch {
            print("Error loading participants: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func uploadGroupPicture() async {
        guard let image = selectedImage else { return }
        
        isUploadingImage = true
        
        do {
            let url = try await MediaService.shared.uploadGroupPicture(image, groupID: conversation.id)
            
            let db = Firestore.firestore()
            try await db.collection("conversations").document(conversation.id).updateData([
                "groupPictureURL": url
            ])
            
            await MainActor.run {
                // Update local conversation object
                conversation.groupPictureURL = url
                isUploadingImage = false
                selectedImage = nil  // Clear selection after upload
            }
        } catch {
            print("Error uploading group picture: \(error)")
            await MainActor.run {
                isUploadingImage = false
            }
        }
    }
    
    private func removeParticipant(_ participant: User) {
        Task {
            do {
                let db = Firestore.firestore()
                
                try await db.collection("conversations").document(conversation.id).updateData([
                    "participantIDs": FieldValue.arrayRemove([participant.id])
                ])
                
                await MainActor.run {
                    participants.removeAll { $0.id == participant.id }
                }
            } catch {
                print("Error removing participant: \(error)")
            }
        }
    }
}

#Preview {
    GroupInfoView(
        conversation: Conversation(
            id: "preview",
            isGroup: true,
            participantIDs: ["user1", "user2", "user3"],
            name: "Murder Case"
        )
    )
    .environmentObject(AuthViewModel())
}
