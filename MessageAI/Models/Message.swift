import Foundation
import SwiftData

enum MessageStatus: String, Codable {
    case sending
    case sent
    case delivered
    case read
}

enum MessageType: String, Codable {
    case text
    case image
    case video
}

@Model
class Message {
    @Attribute(.unique) var id: String
    var conversationID: String
    var senderID: String
    var content: String
    var timestamp: Date
    var statusRaw: String
    var typeRaw: String
    var mediaURL: String?
    var readBy: [String]
    
    var status: MessageStatus {
        get { MessageStatus(rawValue: statusRaw) ?? .sending }
        set { statusRaw = newValue.rawValue }
    }
    
    var type: MessageType {
        get { MessageType(rawValue: typeRaw) ?? .text }
        set { typeRaw = newValue.rawValue }
    }
    
    init(id: String, conversationID: String, senderID: String, content: String, timestamp: Date = Date(), status: MessageStatus = .sending, type: MessageType = .text, mediaURL: String? = nil, readBy: [String] = []) {
        self.id = id
        self.conversationID = conversationID
        self.senderID = senderID
        self.content = content
        self.timestamp = timestamp
        self.statusRaw = status.rawValue
        self.typeRaw = type.rawValue
        self.mediaURL = mediaURL
        self.readBy = readBy
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "conversationID": conversationID,
            "senderID": senderID,
            "content": content,
            "timestamp": timestamp,
            "status": statusRaw,
            "type": typeRaw,
            "readBy": readBy
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
              let content = data["content"] as? String else {
            return nil
        }
        
        let timestamp = (data["timestamp"] as? Date) ?? Date()
        let statusRaw = data["status"] as? String ?? MessageStatus.sent.rawValue
        let status = MessageStatus(rawValue: statusRaw) ?? .sent
        let typeRaw = data["type"] as? String ?? MessageType.text.rawValue
        let type = MessageType(rawValue: typeRaw) ?? .text
        let mediaURL = data["mediaURL"] as? String
        let readBy = data["readBy"] as? [String] ?? []
        
        return Message(
            id: id,
            conversationID: conversationID,
            senderID: senderID,
            content: content,
            timestamp: timestamp,
            status: status,
            type: type,
            mediaURL: mediaURL,
            readBy: readBy
        )
    }
}
