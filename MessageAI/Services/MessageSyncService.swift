//
//  MessageSyncService.swift
//  MessageAI
//
//  Handles offline message queue and syncing
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import SwiftData
import Combine

@MainActor
class MessageSyncService: ObservableObject {
    static let shared = MessageSyncService()
    
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var pendingMessageCount: Int = 0
    
    private var syncTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 2.0
    
    private init() {
        observeNetworkChanges()
    }
    
    // MARK: - Network Observation
    
    private func observeNetworkChanges() {
        NetworkMonitor.shared.$isConnected
            .sink { [weak self] isConnected in
                if isConnected {
                    print("📤 MessageSync: Network connected, starting sync...")
                    Task {
                        await self?.syncPendingMessages()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Queue Message for Sending
    
    func queueMessage(
        _ message: Message,
        conversationID: String,
        currentUserID: String,
        modelContext: ModelContext
    ) async throws {
        print("📝 MessageSync: Queuing message \(message.id)")
        
        // Save to SwiftData immediately
        var localMessage = message
        localMessage.statusRaw = NetworkMonitor.shared.isConnected ? "sending" : "pending"
        
        modelContext.insert(localMessage)
        try modelContext.save()
        
        print("✅ MessageSync: Message saved locally with status: \(localMessage.statusRaw)")
        
        // If online, attempt to send immediately
        if NetworkMonitor.shared.isConnected {
            try await sendMessage(localMessage, conversationID: conversationID)
        } else {
            print("📡 MessageSync: Offline - message queued for later sync")
            await updatePendingCount()
        }
    }
    
    // MARK: - Send Message
    
    private func sendMessage(_ message: Message, conversationID: String) async throws {
        let db = Firestore.firestore()
        
        var messageData = message.toDictionary()
        messageData["timestamp"] = Timestamp(date: message.timestamp)
        messageData["status"] = "sent"
        
        // Upload to Firestore
        try await db.collection("conversations")
            .document(conversationID)
            .collection("messages")
            .document(message.id)
            .setData(messageData)
        
        // Update conversation last message
        try await db.collection("conversations")
            .document(conversationID)
            .updateData([
                "lastMessage": message.content,
                "lastMessageTime": Timestamp(date: Date()),
                "lastSenderID": message.senderID
            ])
        
        print("✅ MessageSync: Message \(message.id) uploaded successfully")
    }
    
    // MARK: - Sync Pending Messages
    
    func syncPendingMessages() async {
        guard NetworkMonitor.shared.isConnected else {
            print("📡 MessageSync: Cannot sync - offline")
            return
        }
        
        guard !isSyncing else {
            print("⏳ MessageSync: Sync already in progress")
            return
        }
        
        isSyncing = true
        print("🔄 MessageSync: Starting sync of pending messages...")
        
        // This will be implemented with SwiftData context
        // For now, just update the flag
        
        await updatePendingCount()
        
        isSyncing = false
        print("✅ MessageSync: Sync completed")
    }
    
    // MARK: - Retry Logic
    
    func retryFailedMessages() async {
        guard NetworkMonitor.shared.isConnected else { return }
        
        print("🔄 MessageSync: Retrying failed messages...")
        await syncPendingMessages()
    }
    
    // MARK: - Helpers
    
    private func updatePendingCount() async {
        // This would query SwiftData for pending messages
        // For now, set to 0
        pendingMessageCount = 0
    }
    
    // MARK: - Batch Sync
    
    func batchSyncMessages(_ messages: [Message], conversationID: String) async throws {
        guard NetworkMonitor.shared.isConnected else {
            throw NSError(domain: "MessageSyncService", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "No internet connection"])
        }
        
        print("📤 MessageSync: Batch syncing \(messages.count) messages...")
        
        let db = Firestore.firestore()
        let batch = db.batch()
        
        for message in messages {
            var messageData = message.toDictionary()
            messageData["timestamp"] = Timestamp(date: message.timestamp)
            messageData["status"] = "sent"
            
            let ref = db.collection("conversations")
                .document(conversationID)
                .collection("messages")
                .document(message.id)
            
            batch.setData(messageData, forDocument: ref)
        }
        
        try await batch.commit()
        print("✅ MessageSync: Batch sync completed for \(messages.count) messages")
    }
}

