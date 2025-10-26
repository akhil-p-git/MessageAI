import Foundation
import FirebaseStorage
import UIKit

@MainActor
class MediaService {
    static let shared = MediaService()
    
    private let storage = Storage.storage()
    
    private init() {}
    
    func uploadImage(_ image: UIImage, conversationID: String) async throws -> String {
        print("🔵 Starting conversation image upload for: \(conversationID)")
        
        // Resize image
        let resizedImage = image.resized(to: CGSize(width: 1024, height: 1024))
        
        // Compress image
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.7) else {
            print("❌ Failed to convert image to JPEG data")
            throw NSError(domain: "MediaService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
        }
        
        print("📊 Image data size: \(imageData.count) bytes")
        
        let filename = "\(UUID().uuidString).jpg"
        let path = "conversations/\(conversationID)/\(filename)"
        let storageRef = storage.reference().child(path)
        
        print("📤 Uploading to: \(path)")
        
        // Upload with metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            let _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
            print("✅ Upload complete, fetching download URL...")
            
            let downloadURL = try await storageRef.downloadURL()
            print("✅ Download URL: \(downloadURL.absoluteString)")
            
            return downloadURL.absoluteString
        } catch {
            print("❌ Upload failed with error: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            throw error
        }
    }
    
    func uploadProfilePicture(_ image: UIImage, userID: String) async throws -> String {
        print("🔵 Starting profile picture upload for user: \(userID)")
        
        // Resize image to max 800x800 to reduce size
        let resizedImage = image.resized(to: CGSize(width: 800, height: 800))
        
        // Compress image
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
            print("❌ Failed to convert image to JPEG data")
            throw NSError(domain: "MediaService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
        }
        
        print("📊 Image data size: \(imageData.count) bytes")
        
        let filename = "profile_\(userID).jpg"
        let path = "profile_pictures/\(filename)"
        let storageRef = storage.reference().child(path)
        
        print("📤 Uploading to: \(path)")
        
        // Upload image with metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            let _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
            print("✅ Upload complete, fetching download URL...")
            
            let downloadURL = try await storageRef.downloadURL()
            print("✅ Download URL: \(downloadURL.absoluteString)")
            
            return downloadURL.absoluteString
        } catch {
            print("❌ Upload failed with error: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            throw error
        }
    }
    
    func deleteProfilePicture(userID: String) async throws {
        let filename = "profile_\(userID).jpg"
        let storageRef = storage.reference().child("profile_pictures/\(filename)")
        
        try await storageRef.delete()
    }
    
    func uploadGroupPicture(_ image: UIImage, groupID: String) async throws -> String {
        print("🔵 Starting group picture upload for group: \(groupID)")
        
        // Resize image to max 800x800
        let resizedImage = image.resized(to: CGSize(width: 800, height: 800))
        
        // Compress image
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
            print("❌ Failed to convert image to JPEG data")
            throw NSError(domain: "MediaService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
        }
        
        let filename = "group_\(groupID).jpg"
        let path = "group_pictures/\(filename)"
        let storageRef = storage.reference().child(path)
        
        print("📤 Uploading to: \(path)")
        
        // Upload image with metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            let _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
            let downloadURL = try await storageRef.downloadURL()
            print("✅ Group picture uploaded: \(downloadURL.absoluteString)")
            return downloadURL.absoluteString
        } catch {
            print("❌ Upload failed: \(error)")
            throw error
        }
    }
}

// MARK: - UIImage Extension for Resizing

extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage {
        let size = self.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Use the smaller ratio to maintain aspect ratio
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
