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
    private let debugMode = true // Set to false in production
    
    private init() {
        // Optionally set region if needed
        // functions = Functions.functions(region: "us-central1")
        if debugMode {
            print("🤖 AIService initialized")
        }
    }
    
    // MARK: - Debug Logging
    
    private func log(_ message: String, type: LogType = .info) {
        guard debugMode else { return }
        
        let emoji: String
        switch type {
        case .info:
            emoji = "ℹ️"
        case .success:
            emoji = "✅"
        case .error:
            emoji = "❌"
        case .warning:
            emoji = "⚠️"
        case .request:
            emoji = "📤"
        case .response:
            emoji = "📥"
        }
        
        print("\(emoji) AIService: \(message)")
    }
    
    private enum LogType {
        case info, success, error, warning, request, response
    }
    
    // MARK: - Health Check
    
    func healthCheck() async -> Bool {
        log("Starting health check...", type: .info)
        
        do {
            // Try to call summarizeThread with a test conversation
            let callable = functions.httpsCallable("summarizeThread")
            _ = try await callable.call([
                "conversationId": "health-check-test",
                "messageLimit": 1
            ])
            log("Health check passed - Firebase Functions are accessible", type: .success)
            return true
        } catch {
            log("Health check failed: \(error.localizedDescription)", type: .error)
            return false
        }
    }
    
    // MARK: - Thread Summarization
    
    func summarizeThread(conversationID: String, messageLimit: Int = 100) async throws -> ConversationSummary {
        log("📤 Calling summarizeThread", type: .request)
        log("ConversationID: \(conversationID), MessageLimit: \(messageLimit)", type: .info)
        
        let callable = functions.httpsCallable("summarizeThread")
        
        do {
            let result = try await callable.call([
                "conversationId": conversationID,
                "messageLimit": messageLimit
            ])
            
            log("📥 Received response from summarizeThread", type: .response)
            
            if let data = result.data as? [String: Any] {
                log("Response data: \(data)", type: .info)
            }
            
            guard let data = result.data as? [String: Any],
                  let summary = ConversationSummary(from: data) else {
                log("Failed to parse summary from response", type: .error)
                throw AIServiceError.parsingError
            }
            
            log("✅ Successfully parsed summary with \(summary.points.count) points", type: .success)
            return summary
        } catch {
            log("❌ Error in summarizeThread: \(error.localizedDescription)", type: .error)
            if let nsError = error as NSError? {
                log("Error domain: \(nsError.domain), code: \(nsError.code)", type: .error)
                log("Error userInfo: \(nsError.userInfo)", type: .error)
            }
            throw AIServiceError.networkError(error)
        }
    }
    
    // MARK: - Action Items Extraction
    
    func extractActionItems(conversationID: String) async throws -> ActionItemsResult {
        log("📤 Calling extractActionItems", type: .request)
        log("ConversationID: \(conversationID)", type: .info)
        
        let callable = functions.httpsCallable("extractActionItems")
        
        do {
            let result = try await callable.call([
                "conversationId": conversationID
            ])
            
            log("📥 Received response from extractActionItems", type: .response)
            
            if let data = result.data as? [String: Any] {
                log("Response data: \(data)", type: .info)
            }
            
            guard let data = result.data as? [String: Any],
                  let actionItems = ActionItemsResult(from: data) else {
                log("Failed to parse action items from response", type: .error)
                throw AIServiceError.parsingError
            }
            
            log("✅ Successfully parsed \(actionItems.items.count) action items", type: .success)
            return actionItems
        } catch {
            log("❌ Error in extractActionItems: \(error.localizedDescription)", type: .error)
            if let nsError = error as NSError? {
                log("Error domain: \(nsError.domain), code: \(nsError.code)", type: .error)
            }
            throw AIServiceError.networkError(error)
        }
    }
    
    // MARK: - Smart Search
    
    func smartSearch(conversationID: String, query: String) async throws -> SmartSearchResults {
        log("📤 Calling smartSearch", type: .request)
        log("ConversationID: \(conversationID), Query: '\(query)'", type: .info)
        
        let callable = functions.httpsCallable("smartSearch")
        
        do {
            let result = try await callable.call([
                "conversationId": conversationID,
                "query": query
            ])
            
            log("📥 Received response from smartSearch", type: .response)
            
            if let data = result.data as? [String: Any] {
                log("Response data: \(data)", type: .info)
            }
            
            guard let data = result.data as? [String: Any],
                  let searchResults = SmartSearchResults(from: data) else {
                log("Failed to parse search results from response", type: .error)
                throw AIServiceError.parsingError
            }
            
            log("✅ Successfully found \(searchResults.results.count) search results", type: .success)
            return searchResults
        } catch {
            log("❌ Error in smartSearch: \(error.localizedDescription)", type: .error)
            throw AIServiceError.networkError(error)
        }
    }
    
    // MARK: - Decision Tracking
    
    func trackDecisions(conversationID: String) async throws -> DecisionsResult {
        log("📤 Calling trackDecisions", type: .request)
        log("ConversationID: \(conversationID)", type: .info)
        
        let callable = functions.httpsCallable("trackDecisions")
        
        do {
            let result = try await callable.call([
                "conversationId": conversationID
            ])
            
            log("📥 Received response from trackDecisions", type: .response)
            
            if let data = result.data as? [String: Any] {
                log("Response data: \(data)", type: .info)
            }
            
            guard let data = result.data as? [String: Any],
                  let decisions = DecisionsResult(from: data) else {
                log("Failed to parse decisions from response", type: .error)
                throw AIServiceError.parsingError
            }
            
            log("✅ Successfully tracked \(decisions.decisions.count) decisions", type: .success)
            return decisions
        } catch {
            log("❌ Error in trackDecisions: \(error.localizedDescription)", type: .error)
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

