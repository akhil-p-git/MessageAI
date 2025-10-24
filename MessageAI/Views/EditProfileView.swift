import SwiftUI
import FirebaseFirestore
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var displayName: String = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isLoading = false
    @State private var isUploadingImage = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    
    var body: some View {
        Button("Test AI") {
            Task {
                do {
                    let summary = try await AIService.shared.summarizeThread(
                        conversationID: "test-id"
                    )
                    print("✅ AI Works! Summary: \(summary.points)")
                } catch {
                    print("❌ Error: \(error)")
                }
            }
        }
        Form {
            Section("Profile Picture") {
                VStack(spacing: 16) {
                    // Profile Picture Display
                    if let selectedImage = selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                    } else {
                        ProfileImageView(
                            url: authViewModel.currentUser?.profilePictureURL,
                            size: 100,
                            fallbackText: displayName
                        )
                    }
                    
                    // Change Photo Button
                    Button(action: { showImagePicker = true }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text(authViewModel.currentUser?.profilePictureURL == nil && selectedImage == nil ? "Add Photo" : "Change Photo")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    
                    // Remove Photo Button
                    if authViewModel.currentUser?.profilePictureURL != nil || selectedImage != nil {
                        Button(action: removePhoto) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Remove Photo")
                            }
                            .font(.subheadline)
                            .foregroundColor(.red)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
            
            Section("Profile Information") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Name")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter display name", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(authViewModel.currentUser?.email ?? "")
                        .foregroundColor(.secondary)
                }
            }
            
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
            }
            
            if showSuccess {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Profile updated successfully!")
                            .foregroundColor(.green)
                    }
                }
            }
            
            Section {
                Button(action: saveProfile) {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Text("Save Changes")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.blue)
                    }
                }
                .disabled(isLoading || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(selectedImage: $selectedImage)
        }
        .onAppear {
            displayName = authViewModel.currentUser?.displayName ?? ""
        }
    }
    
    private func removePhoto() {
        selectedImage = nil
        
        guard let currentUser = authViewModel.currentUser,
              currentUser.profilePictureURL != nil else {
            return
        }
        
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                // Delete from Storage
                try await MediaService.shared.deleteProfilePicture(userID: currentUser.id)
                
                // Update Firestore
                let db = Firestore.firestore()
                try await db.collection("users").document(currentUser.id).updateData([
                    "profilePictureURL": FieldValue.delete()
                ])
                
                // Update local user
                var updatedUser = currentUser
                updatedUser.profilePictureURL = nil
                await MainActor.run {
                    authViewModel.currentUser = updatedUser
                    showSuccess = true
                    isLoading = false
                }
            } catch {
                print("❌ Error removing photo: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to remove photo: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func saveProfile() {
        guard let currentUser = authViewModel.currentUser else { return }
        
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "Display name cannot be empty"
            return
        }
        
        isLoading = true
        errorMessage = nil
        showSuccess = false
        
        Task {
            do {
                let db = Firestore.firestore()
                var updateData: [String: Any] = [:]
                
                // Upload profile picture first if selected
                var newProfileURL: String? = currentUser.profilePictureURL
                if let image = selectedImage {
                    print("📸 Uploading profile picture...")
                    do {
                        let url = try await MediaService.shared.uploadProfilePicture(image, userID: currentUser.id)
                        updateData["profilePictureURL"] = url
                        newProfileURL = url
                        print("✅ Profile picture uploaded: \(url)")
                    } catch {
                        print("❌ Failed to upload profile picture: \(error)")
                        await MainActor.run {
                            errorMessage = "Failed to upload image: \(error.localizedDescription)"
                            isLoading = false
                        }
                        return
                    }
                }
                
                // Update display name if changed
                if trimmedName != currentUser.displayName {
                    updateData["displayName"] = trimmedName
                }
                
                // Update Firestore if there are changes
                if !updateData.isEmpty {
                    print("💾 Updating Firestore with: \(updateData)")
                    try await db.collection("users").document(currentUser.id).updateData(updateData)
                    print("✅ Firestore updated successfully")
                }
                
                // Update local user model
                var updatedUser = currentUser
                updatedUser.displayName = trimmedName
                updatedUser.profilePictureURL = newProfileURL
                
                await MainActor.run {
                    authViewModel.currentUser = updatedUser
                    showSuccess = true
                    isLoading = false
                }
                
                // Dismiss after showing success
                try await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Error in saveProfile: \(error)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
            .environmentObject(AuthViewModel())
    }
}
