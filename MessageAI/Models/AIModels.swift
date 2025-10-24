//
//  AIModels.swift
//  MessageAI
//
//  Data models for AI features
//

import Foundation

// MARK: - Confidence Level

enum ConfidenceLevel: String, Codable {
    case high
    case medium
    case low
}

// MARK: - Decision

struct Decision: Identifiable, Codable {
    let id: String
    let decision: String
    let topic: String
    let participants: [String]
    let timestamp: String?
    let confidence: ConfidenceLevel
    
    init(id: String = UUID().uuidString, decision: String, topic: String, participants: [String], timestamp: String? = nil, confidence: ConfidenceLevel) {
        self.id = id
        self.decision = decision
        self.topic = topic
        self.participants = participants
        self.timestamp = timestamp
        self.confidence = confidence
    }
    
    init?(from dict: [String: Any]) {
        guard let decision = dict["decision"] as? String,
              let topic = dict["topic"] as? String else {
            return nil
        }
        
        self.id = dict["id"] as? String ?? UUID().uuidString
        self.decision = decision
        self.topic = topic
        self.participants = dict["participantsInvolved"] as? [String] ?? []
        self.timestamp = dict["timestamp"] as? String
        
        // Parse confidence
        if let confidenceStr = dict["confidence"] as? String {
            self.confidence = ConfidenceLevel(rawValue: confidenceStr) ?? .medium
        } else {
            self.confidence = .medium
        }
    }
}

// MARK: - Action Item

struct ActionItem: Identifiable, Codable {
    let id: String
    let task: String
    let assignee: String?
    let deadline: Date?
    let priority: String?
    
    init(id: String = UUID().uuidString, task: String, assignee: String? = nil, deadline: Date? = nil, priority: String? = nil) {
        self.id = id
        self.task = task
        self.assignee = assignee
        self.deadline = deadline
        self.priority = priority
    }
    
    init?(from dict: [String: Any]) {
        guard let task = dict["task"] as? String else {
            return nil
        }
        
        self.id = dict["id"] as? String ?? UUID().uuidString
        self.task = task
        self.assignee = dict["assignee"] as? String
        self.priority = dict["priority"] as? String
        
        // Parse deadline
        if let deadlineStr = dict["deadline"] as? String {
            let formatter = ISO8601DateFormatter()
            self.deadline = formatter.date(from: deadlineStr)
        } else {
            self.deadline = nil
        }
    }
}

// MARK: - Search Result

struct SearchResult: Identifiable, Codable {
    let id: String
    let message: String
    let sender: String?
    let timestamp: Date
    let relevanceScore: Double
    
    init(id: String = UUID().uuidString, message: String, sender: String? = nil, timestamp: Date, relevanceScore: Double) {
        self.id = id
        self.message = message
        self.sender = sender
        self.timestamp = timestamp
        self.relevanceScore = relevanceScore
    }
    
    init?(from dict: [String: Any]) {
        guard let message = dict["message"] as? String else {
            return nil
        }
        
        self.id = dict["id"] as? String ?? UUID().uuidString
        self.message = message
        self.sender = dict["sender"] as? String
        self.relevanceScore = dict["relevanceScore"] as? Double ?? 0.0
        
        // Parse timestamp
        if let timestampStr = dict["timestamp"] as? String {
            let formatter = ISO8601DateFormatter()
            self.timestamp = formatter.date(from: timestampStr) ?? Date()
        } else if let timestamp = dict["timestamp"] as? Date {
            self.timestamp = timestamp
        } else {
            self.timestamp = Date()
        }
    }
}

// MARK: - Conversation Summary

struct ConversationSummary: Codable {
    let points: [String]
    let messageCount: Int
    let timestamp: Date
    
    init(points: [String], messageCount: Int, timestamp: Date = Date()) {
        self.points = points
        self.messageCount = messageCount
        self.timestamp = timestamp
    }
    
    init?(from dict: [String: Any]) {
        guard let points = dict["summary"] as? [String] else {
            return nil
        }
        
        self.points = points
        self.messageCount = dict["messageCount"] as? Int ?? 0
        
        // Parse timestamp
        if let timestampStr = dict["timestamp"] as? String {
            let formatter = ISO8601DateFormatter()
            self.timestamp = formatter.date(from: timestampStr) ?? Date()
        } else {
            self.timestamp = Date()
        }
    }
}

// MARK: - AI Response Wrappers

struct ActionItemsResult: Codable {
    let items: [ActionItem]
    
    init?(from dict: [String: Any]) {
        // Try multiple possible keys for flexibility
        let itemsArray: [[String: Any]]
        
        if let items = dict["items"] as? [[String: Any]] {
            itemsArray = items
        } else if let actionItems = dict["actionItems"] as? [[String: Any]] {
            itemsArray = actionItems
        } else {
            print("❌ ActionItemsResult: Could not find 'items' or 'actionItems' key in response")
            print("   Available keys: \(dict.keys)")
            return nil
        }
        
        self.items = itemsArray.compactMap { ActionItem(from: $0) }
    }
}

struct DecisionsResult: Codable {
    let decisions: [Decision]
    
    init?(from dict: [String: Any]) {
        guard let decisionsArray = dict["decisions"] as? [[String: Any]] else {
            return nil
        }
        
        self.decisions = decisionsArray.compactMap { Decision(from: $0) }
    }
}

struct SmartSearchResults: Codable {
    let results: [SearchResult]
    
    init?(from dict: [String: Any]) {
        guard let resultsArray = dict["results"] as? [[String: Any]] else {
            return nil
        }
        
        self.results = resultsArray.compactMap { SearchResult(from: $0) }
    }
}

