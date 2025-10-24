//
//  AIService.swift
//  MessageAI
//
//  Service layer for AI features via Firebase Cloud Functions
//

import Foundation
import FirebaseFunctions

enum AIServiceError: LocalizedError {
    case invalidResponse
    case networkError(Error)
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from AI service"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingError:
            return "Failed to parse AI response"
        }
    }
}

@MainActor
class AIService {
    static let shared = AIService()
    private let functions = Functions.functions()
    
    private init() {
        // Optionally set region if needed
        // functions = Functions.functions(region: "us-central1")
    }
    
    // MARK: - Thread Summarization
    
    func summarizeThread(conversationID: String, messageLimit: Int = 100) async throws -> ConversationSummary {
        let callable = functions.httpsCallable("summarizeThread")
        
        do {
            let result = try await callable.call([
                "conversationId": conversationID,
                "messageLimit": messageLimit
            ])
            
            guard let data = result.data as? [String: Any],
                  let summary = ConversationSummary(from: data) else {
                throw AIServiceError.parsingError
            }
            
            return summary
        } catch {
            throw AIServiceError.networkError(error)
        }
    }
    
    // MARK: - Action Items Extraction
    
    func extractActionItems(conversationID: String) async throws -> ActionItemsResult {
        let callable = functions.httpsCallable("extractActionItems")
        
        do {
            let result = try await callable.call([
                "conversationId": conversationID
            ])
            
            guard let data = result.data as? [String: Any],
                  let actionItems = ActionItemsResult(from: data) else {
                throw AIServiceError.parsingError
            }
            
            return actionItems
        } catch {
            throw AIServiceError.networkError(error)
        }
    }
    
    // MARK: - Smart Search
    
    func smartSearch(conversationID: String, query: String) async throws -> SmartSearchResults {
        let callable = functions.httpsCallable("smartSearch")
        
        do {
            let result = try await callable.call([
                "conversationId": conversationID,
                "query": query
            ])
            
            guard let data = result.data as? [String: Any],
                  let searchResults = SmartSearchResults(from: data) else {
                throw AIServiceError.parsingError
            }
            
            return searchResults
        } catch {
            throw AIServiceError.networkError(error)
        }
    }
    
    // MARK: - Decision Tracking
    
    func trackDecisions(conversationID: String) async throws -> DecisionsResult {
        let callable = functions.httpsCallable("trackDecisions")
        
        do {
            let result = try await callable.call([
                "conversationId": conversationID
            ])
            
            guard let data = result.data as? [String: Any],
                  let decisions = DecisionsResult(from: data) else {
                throw AIServiceError.parsingError
            }
            
            return decisions
        } catch {
            throw AIServiceError.networkError(error)
        }
    }
    
    // MARK: - Priority Detection
    
    func detectPriority(messageID: String, conversationID: String) async throws -> PriorityResult {
        let callable = functions.httpsCallable("detectPriority")
        
        do {
            let result = try await callable.call([
                "messageId": messageID,
                "conversationId": conversationID
            ])
            
            guard let data = result.data as? [String: Any],
                  let isUrgent = data["isUrgent"] as? Bool,
                  let score = data["urgencyScore"] as? Double else {
                throw AIServiceError.parsingError
            }
            
            let reason = data["reason"] as? String
            
            return PriorityResult(
                isUrgent: isUrgent,
                urgencyScore: score,
                reason: reason
            )
        } catch {
            throw AIServiceError.networkError(error)
        }
    }
}

// MARK: - Priority Result Model

struct PriorityResult: Codable {
    let isUrgent: Bool
    let urgencyScore: Double
    let reason: String?
}

