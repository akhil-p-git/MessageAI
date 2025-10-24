//
//  Message.swift
//  MessageAI
//

import Foundation
import SwiftData

enum MessageType: String, Codable {
    case text
    case image
    case voice
}

enum MessageStatus: String, Codable {
    case pending    // Queued for sending (offline)
    case sending    // Currently being sent
    case sent       // Successfully sent
    case delivered  // Delivered to recipient
    case read       // Read by recipient
    case failed     // Failed to send after retries
    
    var isPendingSync: Bool {
        return self == .pending || self == .failed
    }
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
    var reactions: [String: [String]]
    var replyToMessageID: String?
    var replyToContent: String?
    var replyToSenderID: String?
    var deletedFor: [String]
    var deletedForEveryone: Bool
    
    // Offline support properties
    var syncAttempts: Int = 0
    var lastSyncAttempt: Date?
    var needsSync: Bool = false
    
    var status: MessageStatus {
        get {
            MessageStatus(rawValue: statusRaw) ?? .sent
        }
        set {
            statusRaw = newValue.rawValue
        }
    }
    
    init(id: String, conversationID: String, senderID: String, content: String, timestamp: Date = Date(), status: MessageStatus = .sent, type: MessageType = .text, mediaURL: String? = nil, readBy: [String] = [], reactions: [String: [String]] = [:], replyToMessageID: String? = nil, replyToContent: String? = nil, replyToSenderID: String? = nil, deletedFor: [String] = [], deletedForEveryone: Bool = false, syncAttempts: Int = 0, lastSyncAttempt: Date? = nil, needsSync: Bool = false) {
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
        self.replyToMessageID = replyToMessageID
        self.replyToContent = replyToContent
        self.replyToSenderID = replyToSenderID
        self.deletedFor = deletedFor
        self.deletedForEveryone = deletedForEveryone
        self.syncAttempts = syncAttempts
        self.lastSyncAttempt = lastSyncAttempt
        self.needsSync = needsSync
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
            "reactions": reactions,
            "deletedFor": deletedFor,
            "deletedForEveryone": deletedForEveryone
        ]
        
        if let mediaURL = mediaURL {
            dict["mediaURL"] = mediaURL
        }
        
        if let replyToMessageID = replyToMessageID {
            dict["replyToMessageID"] = replyToMessageID
        }
        
        if let replyToContent = replyToContent {
            dict["replyToContent"] = replyToContent
        }
        
        if let replyToSenderID = replyToSenderID {
            dict["replyToSenderID"] = replyToSenderID
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
        let replyToMessageID = data["replyToMessageID"] as? String
        let replyToContent = data["replyToContent"] as? String
        let replyToSenderID = data["replyToSenderID"] as? String
        let deletedFor = data["deletedFor"] as? [String] ?? []
        let deletedForEveryone = data["deletedForEveryone"] as? Bool ?? false
        
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
            reactions: reactions,
            replyToMessageID: replyToMessageID,
            replyToContent: replyToContent,
            replyToSenderID: replyToSenderID,
            deletedFor: deletedFor,
            deletedForEveryone: deletedForEveryone
        )
    }
}
