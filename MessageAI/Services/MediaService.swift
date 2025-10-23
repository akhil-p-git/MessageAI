import Foundation
import FirebaseStorage
import UIKit

@MainActor
class MediaService {
    static let shared = MediaService()
    
    private let storage = Storage.storage()
    
    private init() {}
    
    func uploadImage(_ image: UIImage, conversationID: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "MediaService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
        }
        
        let filename = "\(UUID().uuidString).jpg"
        let storageRef = storage.reference().child("conversations/\(conversationID)/\(filename)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        return downloadURL.absoluteString
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
        let storageRef = storage.reference().child("profile_pictures/\(filename)")
        
        print("📤 Uploading to Firebase Storage: profile_pictures/\(filename)")
        
        // Upload image with metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        print("✅ Upload complete, fetching download URL...")
        
        // Get download URL
        let downloadURL = try await storageRef.downloadURL()
        print("✅ Download URL received: \(downloadURL.absoluteString)")
        
        return downloadURL.absoluteString
    }
    
    func deleteProfilePicture(userID: String) async throws {
        let filename = "profile_\(userID).jpg"
        let storageRef = storage.reference().child("profile_pictures/\(filename)")
        
        try await storageRef.delete()
    }
}

// MARK: - UIImage Extension for Resizing

extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
