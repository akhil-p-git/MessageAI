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
    
    init(id: String, isGroup: Bool, name: String? = nil, participantIDs: [String], lastMessage: String? = nil, lastMessageTime: Date = Date(), unreadCount: Int = 0) {
        self.id = id
        self.isGroup = isGroup
        self.name = name
        self.participantIDs = participantIDs
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.unreadCount = unreadCount
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
        
        return Conversation(
            id: id,
            isGroup: isGroup,
            name: name,
            participantIDs: participantIDs,
            lastMessage: lastMessage,
            lastMessageTime: lastMessageTime,
            unreadCount: unreadCount
        )
    }
}
