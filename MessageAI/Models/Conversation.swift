//
//  Conversation.swift
//  MessageAI
//
//  SwiftData Conversation model compatible with Firestore
//

import Foundation
import SwiftData

@Model
class Conversation {
    @Attribute(.unique) var id: String
    var isGroup: Bool
    var name: String?
    var participantIDs: [String]
    var lastMessage: String?
    var lastMessageTime: Date
    var unreadCount: Int
    var lastReadTime: Date?
    
    init(id: String, isGroup: Bool, name: String? = nil, participantIDs: [String], lastMessage: String? = nil, lastMessageTime: Date = Date(), unreadCount: Int = 0, lastReadTime: Date? = nil) {
        self.id = id
        self.isGroup = isGroup
        self.name = name
        self.participantIDs = participantIDs
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.unreadCount = unreadCount
        self.lastReadTime = lastReadTime
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "isGroup": isGroup,
            "participantIDs": participantIDs,
            "lastMessageTime": lastMessageTime,
            "unreadCount": unreadCount
        ]
        
        if let name = name {
            dict["name"] = name
        }
        
        if let lastMessage = lastMessage {
            dict["lastMessage"] = lastMessage
        }
        
        if let lastReadTime = lastReadTime {
            dict["lastReadTime"] = lastReadTime
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
        let lastMessageTime = (data["lastMessageTime"] as? Date) ?? Date()
        let unreadCount = data["unreadCount"] as? Int ?? 0
        let lastReadTime = data["lastReadTime"] as? Date
        
        return Conversation(
            id: id,
            isGroup: isGroup,
            name: name,
            participantIDs: participantIDs,
            lastMessage: lastMessage,
            lastMessageTime: lastMessageTime,
            unreadCount: unreadCount,
            lastReadTime: lastReadTime
        )
    }
}
