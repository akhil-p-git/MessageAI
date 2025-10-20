import Foundation
import SwiftData

@Model
class User {
    @Attribute(.unique) var id: String
    var email: String
    var displayName: String
    var profilePictureURL: String?
    var isOnline: Bool
    var lastSeen: Date
    var fcmToken: String?
    
    init(id: String, email: String, displayName: String, profilePictureURL: String? = nil, isOnline: Bool = false, lastSeen: Date = Date(), fcmToken: String? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.profilePictureURL = profilePictureURL
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.fcmToken = fcmToken
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "email": email,
            "displayName": displayName,
            "isOnline": isOnline,
            "lastSeen": lastSeen
        ]
        
        if let profilePictureURL = profilePictureURL {
            dict["profilePictureURL"] = profilePictureURL
        }
        
        if let fcmToken = fcmToken {
            dict["fcmToken"] = fcmToken
        }
        
        return dict
    }
    
    static func fromDictionary(_ data: [String: Any]) -> User? {
        guard let id = data["id"] as? String,
              let email = data["email"] as? String,
              let displayName = data["displayName"] as? String else {
            return nil
        }
        
        let isOnline = data["isOnline"] as? Bool ?? false
        let lastSeen = (data["lastSeen"] as? Date) ?? Date()
        let profilePictureURL = data["profilePictureURL"] as? String
        let fcmToken = data["fcmToken"] as? String
        
        return User(
            id: id,
            email: email,
            displayName: displayName,
            profilePictureURL: profilePictureURL,
            isOnline: isOnline,
            lastSeen: lastSeen,
            fcmToken: fcmToken
        )
    }
}

