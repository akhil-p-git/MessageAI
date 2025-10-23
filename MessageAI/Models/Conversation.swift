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
    var participantIDs: [String]
    var lastMessage: String?
    var lastMessageTime: Date?
    var lastSenderID: String?
    var creatorID: String?
    
    init(id: String, isGroup: Bool, participantIDs: [String], name: String? = nil, lastMessage: String? = nil, lastMessageTime: Date? = nil, lastSenderID: String? = nil, creatorID: String? = nil) {
        self.id = id
        self.isGroup = isGroup
        self.participantIDs = participantIDs
        self.name = name
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.lastSenderID = lastSenderID
        self.creatorID = creatorID
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "isGroup": isGroup,
            "participantIDs": participantIDs
        ]
        
        if let name = name {
            dict["name"] = name
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
        let lastMessage = data["lastMessage"] as? String
        let lastMessageTime = data["lastMessageTime"] as? Date
        let lastSenderID = data["lastSenderID"] as? String
        let creatorID = data["creatorID"] as? String
        
        return Conversation(
            id: id,
            isGroup: isGroup,
            participantIDs: participantIDs,
            name: name,
            lastMessage: lastMessage,
            lastMessageTime: lastMessageTime,
            lastSenderID: lastSenderID,
            creatorID: creatorID
        )
    }
}
