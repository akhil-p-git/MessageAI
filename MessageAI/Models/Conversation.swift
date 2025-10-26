//
//  Conversation.swift
//  MessageAI
//

import Foundation
import SwiftData

@Model
class Conversation: Identifiable {
    @Attribute(.unique) var id: String
    var isGroup: Bool
    var name: String?
    var groupPictureURL: String?
    var participantIDs: [String]
    var lastMessage: String?
    var lastMessageTime: Date?
    var lastSenderID: String?
    var lastMessageID: String?
    var unreadBy: [String] = []
    var creatorID: String?
    var deletedBy: [String] = []  // Users who have deleted this conversation from their view
    
    init(id: String, isGroup: Bool, participantIDs: [String], name: String? = nil, groupPictureURL: String? = nil, lastMessage: String? = nil, lastMessageTime: Date? = nil, lastSenderID: String? = nil, lastMessageID: String? = nil, unreadBy: [String] = [], creatorID: String? = nil, deletedBy: [String] = []) {
        self.id = id
        self.isGroup = isGroup
        self.participantIDs = participantIDs
        self.name = name
        self.groupPictureURL = groupPictureURL
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.lastSenderID = lastSenderID
        self.lastMessageID = lastMessageID
        self.unreadBy = unreadBy
        self.creatorID = creatorID
        self.deletedBy = deletedBy
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "isGroup": isGroup,
            "participantIDs": participantIDs,
            "unreadBy": unreadBy,
            "deletedBy": deletedBy
        ]
        
        if let name = name {
            dict["name"] = name
        }
        
        if let groupPictureURL = groupPictureURL {
            dict["groupPictureURL"] = groupPictureURL
        }
        
        if let lastMessage = lastMessage {
            dict["lastMessage"] = lastMessage
        }
        
        if let lastMessageTime = lastMessageTime {
            dict["lastMessageTime"] = lastMessageTime
        }
        
        if let lastSenderID = lastSenderID {
            dict["lastSenderID"] = lastSenderID
        }
        
        if let lastMessageID = lastMessageID {
            dict["lastMessageID"] = lastMessageID
        }
        
        if let creatorID = creatorID {
            dict["creatorID"] = creatorID
        }
        
        return dict
    }
    
    static func fromDictionary(_ data: [String: Any]) -> Conversation? {
        guard let id = data["id"] as? String,
              let isGroup = data["isGroup"] as? Bool,
              let participantIDs = data["participantIDs"] as? [String] else {
            return nil
        }
        
        let name = data["name"] as? String
        let groupPictureURL = data["groupPictureURL"] as? String
        let lastMessage = data["lastMessage"] as? String
        let lastMessageTime = data["lastMessageTime"] as? Date
        let lastSenderID = data["lastSenderID"] as? String
        let lastMessageID = data["lastMessageID"] as? String
        let unreadBy = data["unreadBy"] as? [String] ?? []
        let creatorID = data["creatorID"] as? String
        let deletedBy = data["deletedBy"] as? [String] ?? []
        
        return Conversation(
            id: id,
            isGroup: isGroup,
            participantIDs: participantIDs,
            name: name,
            groupPictureURL: groupPictureURL,
            lastMessage: lastMessage,
            lastMessageTime: lastMessageTime,
            lastSenderID: lastSenderID,
            lastMessageID: lastMessageID,
            unreadBy: unreadBy,
            creatorID: creatorID,
            deletedBy: deletedBy
        )
    }
}
