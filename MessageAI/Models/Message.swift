//
//  Message.swift
//  MessageAI
//
//  SwiftData Message model compatible with Firestore
//

import Foundation
import SwiftData

enum MessageType: String, Codable {
    case text
    case image
    case voice
}

enum MessageStatus: String, Codable {
    case sending
    case sent
    case delivered
    case read
}

@Model
class Message: Identifiable {
    @Attribute(.unique) var id: String
    var conversationID: String
    var senderID: String
    var content: String
    var timestamp: Date
    var statusRaw: String
    var type: MessageType
    var mediaURL: String?
    var readBy: [String]
    var reactions: [String: [String]]  // [emoji: [userIDs]]
    
    var status: MessageStatus {
        get {
            MessageStatus(rawValue: statusRaw) ?? .sent
        }
        set {
            statusRaw = newValue.rawValue
        }
    }
    
    init(id: String, conversationID: String, senderID: String, content: String, timestamp: Date = Date(), status: MessageStatus = .sent, type: MessageType = .text, mediaURL: String? = nil, readBy: [String] = [], reactions: [String: [String]] = [:]) {
        self.id = id
        self.conversationID = conversationID
        self.senderID = senderID
        self.content = content
        self.timestamp = timestamp
        self.statusRaw = status.rawValue
        self.type = type
        self.mediaURL = mediaURL
        self.readBy = readBy
        self.reactions = reactions
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "conversationID": conversationID,
            "senderID": senderID,
            "content": content,
            "timestamp": timestamp,
            "type": type.rawValue,
            "readBy": readBy,
            "reactions": reactions
        ]
        
        if let mediaURL = mediaURL {
            dict["mediaURL"] = mediaURL
        }
        
        return dict
    }
    
    static func fromDictionary(_ data: [String: Any]) -> Message? {
        guard let id = data["id"] as? String,
              let conversationID = data["conversationID"] as? String,
              let senderID = data["senderID"] as? String,
              let content = data["content"] as? String,
              let timestamp = data["timestamp"] as? Date else {
            return nil
        }
        
        let typeString = data["type"] as? String ?? "text"
        let type = MessageType(rawValue: typeString) ?? .text
        
        let statusString = data["status"] as? String ?? "sent"
        let status = MessageStatus(rawValue: statusString) ?? .sent
        
        let mediaURL = data["mediaURL"] as? String
        let readBy = data["readBy"] as? [String] ?? []
        let reactions = data["reactions"] as? [String: [String]] ?? [:]
        
        return Message(
            id: id,
            conversationID: conversationID,
            senderID: senderID,
            content: content,
            timestamp: timestamp,
            status: status,
            type: type,
            mediaURL: mediaURL,
            readBy: readBy,
            reactions: reactions
        )
    }
}
