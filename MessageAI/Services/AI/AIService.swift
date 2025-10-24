//
//  AIService.swift
//  MessageAI
//
//  Service layer for AI features via Firebase Cloud Functions
//

import Foundation
import FirebaseFunctions
import FirebaseFirestore
import SwiftUI

enum AIServiceError: LocalizedError {
    case invalidResponse
    case networkError(Error)
    case parsingError
    case unauthenticated
    case functionNotFound(String)
    case permissionDenied
    case timeout
    case retryLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from AI service"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingError:
            return "Failed to parse AI response"
        case .unauthenticated:
            return "Please sign in to use AI features"
        case .functionNotFound(let name):
            return "AI function '\(name)' not found. Please deploy Firebase Functions."
        case .permissionDenied:
            return "Permission denied. Check your Firebase security rules."
        case .timeout:
            return "Request timed out. Please check your internet connection."
        case .retryLimitExceeded:
            return "Failed after multiple retries. Please try again later."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .unauthenticated:
            return "Sign out and sign back in to refresh your authentication."
        case .functionNotFound:
            return "Deploy your Firebase Cloud Functions using 'firebase deploy --only functions'"
        case .permissionDenied:
            return "Check Firebase console for security rules configuration."
        case .timeout, .networkError:
            return "Check your internet connection and try again."
        case .retryLimitExceeded:
            return "The service may be temporarily unavailable. Please try again in a few minutes."
        default:
            return nil
        }
    }
}

@MainActor
class AIService {
    static let shared = AIService()
    private let functions = Functions.functions()
    private let debugMode = true // Set to false in production
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 1.0 // seconds
    
    private init() {
        // Optionally set region if needed
        // functions = Functions.functions(region: "us-central1")
        if debugMode {
            print("🤖 AIService initialized")
        }
    }
    
    // MARK: - Retry Logic
    
    private func executeWithRetry<T>(
        functionName: String,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                log("Attempt \(attempt) of \(maxRetries)", type: .info)
                return try await operation()
            } catch {
                lastError = error
                
                // Check if error is retryable
                if !isRetryableError(error) {
                    log("Non-retryable error encountered", type: .error)
                    throw parseFirebaseError(error, functionName: functionName)
                }
                
                // Don't retry on last attempt
                if attempt < maxRetries {
                    let delay = baseRetryDelay * pow(2.0, Double(attempt - 1))
                    log("Retrying in \(delay) seconds...", type: .warning)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        log("Max retries exceeded", type: .error)
        throw AIServiceError.retryLimitExceeded
    }
    
    private func isRetryableError(_ error: Error) -> Bool {
        let nsError = error as NSError
        
        // Retry on network errors
        if nsError.domain == NSURLErrorDomain {
            let retryableCodes = [
                NSURLErrorTimedOut,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorNotConnectedToInternet
            ]
            return retryableCodes.contains(nsError.code)
        }
        
        // Retry on server errors (5xx)
        if let functionsError = error as? FunctionsErrorCode {
            return functionsError == .unavailable || functionsError == .deadlineExceeded
        }
        
        return false
    }
    
    private func parseFirebaseError(_ error: Error, functionName: String) -> AIServiceError {
        let nsError = error as NSError
        
        log("Parsing error - Domain: \(nsError.domain), Code: \(nsError.code)", type: .error)
        log("Error description: \(error.localizedDescription)", type: .error)
        
        // Check for Functions-specific errors
        if nsError.domain == "FIRFunctionsErrorDomain" {
            switch nsError.code {
            case FunctionsErrorCode.unauthenticated.rawValue:
                log("Error: User not authenticated", type: .error)
                return .unauthenticated
            case FunctionsErrorCode.notFound.rawValue:
                log("Error: Function '\(functionName)' not found", type: .error)
                return .functionNotFound(functionName)
            case FunctionsErrorCode.permissionDenied.rawValue:
                log("Error: Permission denied", type: .error)
                return .permissionDenied
            case FunctionsErrorCode.deadlineExceeded.rawValue:
                log("Error: Request timeout", type: .error)
                return .timeout
            default:
                break
            }
        }
        
        // Check for network errors
        if nsError.domain == NSURLErrorDomain {
            if nsError.code == NSURLErrorTimedOut {
                return .timeout
            }
        }
        
        return .networkError(error)
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
        
        return try await executeWithRetry(functionName: "summarizeThread") {
            let callable = self.functions.httpsCallable("summarizeThread")
            
            let result = try await callable.call([
            "conversationId": conversationID,
            "messageLimit": messageLimit
            ])
            
            self.log("📥 Received response from summarizeThread", type: .response)
        
            if let data = result.data as? [String: Any] {
                self.log("Response data: \(data)", type: .info)
            }
            
            guard let data = result.data as? [String: Any],
                  let summary = ConversationSummary(from: data) else {
                self.log("Failed to parse summary from response", type: .error)
                throw AIServiceError.parsingError
            }
            
            self.log("✅ Successfully parsed summary with \(summary.points.count) points", type: .success)
            return summary
        }
    }
    
    // MARK: - Action Items Extraction
    
    func extractActionItems(conversationID: String) async throws -> ActionItemsResult {
        log("📤 Calling extractActionItems", type: .request)
        log("ConversationID: \(conversationID)", type: .info)
        
        return try await executeWithRetry(functionName: "extractActionItems") {
            let callable = self.functions.httpsCallable("extractActionItems")
            
            let result = try await callable.call([
                "conversationId": conversationID
            ])
            
            self.log("📥 Received response from extractActionItems", type: .response)
            
            if let data = result.data as? [String: Any] {
                self.log("Response data: \(data)", type: .info)
            }
            
            guard let data = result.data as? [String: Any],
                  let actionItems = ActionItemsResult(from: data) else {
                self.log("Failed to parse action items from response", type: .error)
                throw AIServiceError.parsingError
            }
            
            self.log("✅ Successfully parsed \(actionItems.items.count) action items", type: .success)
            return actionItems
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
        
        return try await executeWithRetry(functionName: "trackDecisions") {
            let callable = self.functions.httpsCallable("trackDecisions")
            
            let result = try await callable.call([
                "conversationId": conversationID
            ])
            
            self.log("📥 Received response from trackDecisions", type: .response)
            
            if let data = result.data as? [String: Any] {
                self.log("Response data: \(data)", type: .info)
            }
            
            guard let data = result.data as? [String: Any],
                  let decisions = DecisionsResult(from: data) else {
                self.log("Failed to parse decisions from response", type: .error)
                throw AIServiceError.parsingError
            }
            
            self.log("✅ Successfully tracked \(decisions.decisions.count) decisions", type: .success)
            return decisions
        }
    }
    
    // MARK: - Priority Detection
    
    func detectPriority(messageText: String, conversationContext: String? = nil) async throws -> PriorityResult {
        log("📤 Calling detectPriority", type: .request)
        log("Message: \(messageText.prefix(50))...", type: .info)
        
        return try await executeWithRetry(functionName: "detectPriority") {
            let callable = self.functions.httpsCallable("detectPriority")
            
            var params: [String: Any] = [
                "messageText": messageText
            ]
            
            if let context = conversationContext {
                params["conversationContext"] = context
            }
            
            let result = try await callable.call(params)
            
            self.log("📥 Received response from detectPriority", type: .response)
            
            guard let data = result.data as? [String: Any] else {
                self.log("Failed to parse priority detection response", type: .error)
                throw AIServiceError.parsingError
            }
            
            self.log("Response data: \(data)", type: .info)
            
            let priority = data["priority"] as? String ?? "low"
            let score = data["score"] as? Double ?? 0.0
            let reason = data["reason"] as? String
            let urgencyIndicators = data["urgencyIndicators"] as? [String] ?? []
            
            let isUrgent = priority == "high"
            
            let priorityResult = PriorityResult(
                isUrgent: isUrgent,
                urgencyScore: score,
                reason: reason,
                priority: priority,
                urgencyIndicators: urgencyIndicators
            )
            
            self.log("✅ Priority detected: \(priority) (score: \(score))", type: .success)
            return priorityResult
        }
    }
    
    // Convenience method for detecting priority of a specific message
    func detectMessagePriority(conversationID: String, messageID: String) async throws -> PriorityResult {
        log("📤 Fetching message for priority detection", type: .info)
        
        // Fetch the message
        let messageDoc = try await Firestore.firestore()
            .collection("conversations")
            .document(conversationID)
            .collection("messages")
            .document(messageID)
            .getDocument()
        
        guard let messageData = messageDoc.data(),
              let messageText = messageData["text"] as? String else {
            throw AIServiceError.parsingError
        }
        
        // Get recent messages for context (last 5 messages)
        let recentMessages = try await Firestore.firestore()
            .collection("conversations")
            .document(conversationID)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: 5)
            .getDocuments()
        
        let contextMessages = recentMessages.documents
            .compactMap { $0.data()["text"] as? String }
            .joined(separator: "\n")
        
        return try await detectPriority(messageText: messageText, conversationContext: contextMessages)
    }
}

// MARK: - Priority Result Model

struct PriorityResult: Codable {
    let isUrgent: Bool
    let urgencyScore: Double
    let reason: String?
    let priority: String // "high", "medium", "low"
    let urgencyIndicators: [String]
    
    init(isUrgent: Bool, urgencyScore: Double, reason: String?, priority: String = "low", urgencyIndicators: [String] = []) {
        self.isUrgent = isUrgent
        self.urgencyScore = urgencyScore
        self.reason = reason
        self.priority = priority
        self.urgencyIndicators = urgencyIndicators
    }
    
    var priorityColor: Color {
        switch priority {
        case "high":
            return .red
        case "medium":
            return .orange
        default:
            return .gray
        }
    }
    
    var priorityIcon: String {
        switch priority {
        case "high":
            return "exclamationmark.triangle.fill"
        case "medium":
            return "exclamationmark.circle.fill"
        default:
            return "circle.fill"
        }
    }
}

