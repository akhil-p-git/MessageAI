//
//  User.swift
//  MessageAI
//

import Foundation
import SwiftData

@Model
class User: Identifiable, Codable {
    @Attribute(.unique) var id: String
    var email: String
    var displayName: String
    var profilePictureURL: String?
    var isOnline: Bool
    var lastSeen: Date?
    var lastHeartbeat: Date?  // Track last heartbeat for accurate online status
    var blockedUsers: [String]
    var showOnlineStatus: Bool
    
    init(id: String, email: String, displayName: String, profilePictureURL: String? = nil, isOnline: Bool = false, lastSeen: Date? = nil, lastHeartbeat: Date? = nil, blockedUsers: [String] = [], showOnlineStatus: Bool = true) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.profilePictureURL = profilePictureURL
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.lastHeartbeat = lastHeartbeat
        self.blockedUsers = blockedUsers
        self.showOnlineStatus = showOnlineStatus
    }
    
    // Computed property to determine if user is actually online
    // Based on last heartbeat being within 30 seconds
    var isActuallyOnline: Bool {
        guard showOnlineStatus, isOnline, let heartbeat = lastHeartbeat else {
            return false
        }
        let timeSinceHeartbeat = Date().timeIntervalSince(heartbeat)
        return timeSinceHeartbeat < 30 // Consider online if heartbeat within 30 seconds
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "email": email,
            "displayName": displayName,
            "isOnline": isOnline,
            "blockedUsers": blockedUsers,
            "showOnlineStatus": showOnlineStatus
        ]
        
        if let profilePictureURL = profilePictureURL {
            dict["profilePictureURL"] = profilePictureURL
        }
        
        if let lastSeen = lastSeen {
            dict["lastSeen"] = lastSeen
        }
        
        if let lastHeartbeat = lastHeartbeat {
            dict["lastHeartbeat"] = lastHeartbeat
        }
        
        return dict
    }
    
    static func fromDictionary(_ data: [String: Any]) -> User? {
        guard let id = data["id"] as? String,
              let email = data["email"] as? String,
              let displayName = data["displayName"] as? String else {
            return nil
        }
        
        let profilePictureURL = data["profilePictureURL"] as? String
        let isOnline = data["isOnline"] as? Bool ?? false
        let lastSeen = data["lastSeen"] as? Date
        let lastHeartbeat = data["lastHeartbeat"] as? Date
        let blockedUsers = data["blockedUsers"] as? [String] ?? []
        let showOnlineStatus = data["showOnlineStatus"] as? Bool ?? true
        
        return User(
            id: id,
            email: email,
            displayName: displayName,
            profilePictureURL: profilePictureURL,
            isOnline: isOnline,
            lastSeen: lastSeen,
            lastHeartbeat: lastHeartbeat,
            blockedUsers: blockedUsers,
            showOnlineStatus: showOnlineStatus
        )
    }
    
    enum CodingKeys: String, CodingKey {
        case id, email, displayName, profilePictureURL, isOnline, lastSeen, lastHeartbeat, blockedUsers, showOnlineStatus
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        displayName = try container.decode(String.self, forKey: .displayName)
        profilePictureURL = try container.decodeIfPresent(String.self, forKey: .profilePictureURL)
        isOnline = try container.decodeIfPresent(Bool.self, forKey: .isOnline) ?? false
        lastSeen = try container.decodeIfPresent(Date.self, forKey: .lastSeen)
        lastHeartbeat = try container.decodeIfPresent(Date.self, forKey: .lastHeartbeat)
        blockedUsers = try container.decodeIfPresent([String].self, forKey: .blockedUsers) ?? []
        showOnlineStatus = try container.decodeIfPresent(Bool.self, forKey: .showOnlineStatus) ?? true
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(profilePictureURL, forKey: .profilePictureURL)
        try container.encode(isOnline, forKey: .isOnline)
        try container.encodeIfPresent(lastSeen, forKey: .lastSeen)
        try container.encodeIfPresent(lastHeartbeat, forKey: .lastHeartbeat)
        try container.encode(blockedUsers, forKey: .blockedUsers)
        try container.encode(showOnlineStatus, forKey: .showOnlineStatus)
    }
}
