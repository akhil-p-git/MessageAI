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
        
        let _ = try await storageRef.putDataAsync(imageData)
        let downloadURL = try await storageRef.downloadURL()
        
        return downloadURL.absoluteString
    }
}
