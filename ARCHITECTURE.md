# MessageAI Architecture Documentation

## Table of Contents

1. [Overview](#overview)
2. [Architecture Pattern](#architecture-pattern)
3. [Project Structure](#project-structure)
4. [Data Flow](#data-flow)
5. [Service Layer](#service-layer)
6. [Models](#models)
7. [Views](#views)
8. [Real-Time Features](#real-time-features)
9. [Offline-First Architecture](#offline-first-architecture)
10. [AI Integration](#ai-integration)
11. [Security](#security)

---

## Overview

MessageAI is built using **MVVM (Model-View-ViewModel)** architecture with a robust service layer. The app is designed to be:

- **Scalable**: Easy to add new features
- **Maintainable**: Clear separation of concerns
- **Testable**: Isolated business logic
- **Performant**: Optimized for real-time updates
- **Offline-First**: Works seamlessly without internet

### Technology Stack

```
┌─────────────────────────────────────┐
│         SwiftUI Views               │  ← Presentation Layer
├─────────────────────────────────────┤
│         ViewModels                  │  ← State Management
├─────────────────────────────────────┤
│         Service Layer               │  ← Business Logic
├─────────────────────────────────────┤
│    SwiftData    │    Firebase       │  ← Data Layer
└─────────────────────────────────────┘
```

---

## Architecture Pattern

### MVVM + Services

```
┌──────────┐         ┌─────────────┐         ┌─────────┐
│   View   │ ◄────── │  ViewModel  │ ◄────── │ Service │
└──────────┘         └─────────────┘         └─────────┘
     │                      │                      │
     │                      │                      │
     ▼                      ▼                      ▼
  User Input          @Published              Firebase
                       State                  Firestore
```

### Responsibilities

| Layer | Responsibility | Example |
|-------|---------------|---------|
| **View** | UI rendering, user interaction | `ChatView.swift` |
| **ViewModel** | State management, validation | `AuthViewModel.swift` |
| **Service** | Business logic, API calls | `AuthService.swift` |
| **Model** | Data structures | `User.swift`, `Message.swift` |

---

## Project Structure

```
MessageAI/
│
├── MessageAI/
│   ├── MessageAIApp.swift           # App entry point
│   │
│   ├── Models/                      # Data Models
│   │   ├── User.swift              # User model (SwiftData + Firestore)
│   │   ├── Conversation.swift      # Conversation model
│   │   ├── Message.swift           # Message model with offline support
│   │   └── AIModels.swift          # AI feature data structures
│   │
│   ├── Views/                       # SwiftUI Views
│   │   ├── Auth/
│   │   │   ├── LoginView.swift
│   │   │   └── SignUpView.swift
│   │   ├── Chat/
│   │   │   ├── ChatView.swift
│   │   │   ├── ConversationListView.swift
│   │   │   ├── NewChatView.swift
│   │   │   └── NewGroupChatView.swift
│   │   ├── AI/
│   │   │   ├── AIFeaturesView.swift
│   │   │   ├── AISummaryCard.swift
│   │   │   ├── ActionItemsView.swift
│   │   │   ├── DecisionsView.swift
│   │   │   ├── SmartSearchView.swift
│   │   │   └── PriorityDetectionView.swift
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift
│   │   │   ├── PrivacySettingsView.swift
│   │   │   └── AppearanceSettingsView.swift
│   │   └── Components/
│   │       ├── MessageBubble.swift
│   │       ├── VoiceMessageBubble.swift
│   │       ├── ImageMessageBubble.swift
│   │       ├── ProfileImageView.swift
│   │       ├── OnlineStatusIndicator.swift
│   │       └── [20+ reusable components]
│   │
│   ├── ViewModels/                  # State Management
│   │   └── AuthViewModel.swift     # Authentication state
│   │
│   └── Services/                    # Business Logic
│       ├── AuthService.swift       # User authentication
│       ├── ConversationService.swift  # Chat operations
│       ├── MediaService.swift      # Image/voice handling
│       ├── AudioRecorderService.swift  # Voice recording
│       ├── AudioPlayerService.swift    # Voice playback
│       ├── AI/
│       │   └── AIService.swift     # AI feature integration
│       ├── NetworkMonitor.swift    # Connectivity monitoring
│       ├── MessageSyncService.swift  # Offline sync
│       ├── PresenceService.swift   # Online status
│       ├── TypingIndicatorService.swift  # Typing status
│       ├── NotificationManager.swift  # Push notifications
│       ├── ThemeManager.swift      # Theme management
│       ├── ReactionService.swift   # Message reactions
│       ├── DeleteMessageService.swift  # Message deletion
│       ├── BlockUserService.swift  # User blocking
│       └── GroupChatService.swift  # Group management
│
├── functions/                       # Firebase Cloud Functions
│   ├── index.js                    # AI agents (Node.js)
│   ├── package.json
│   └── .env                        # OpenAI API key
│
├── firestore.rules                  # Firestore security rules
├── storage.rules                    # Storage security rules
└── firebase.json                    # Firebase configuration
```

---

## Data Flow

### Message Sending Flow

```
1. User types message in ChatView
   ↓
2. ChatView calls sendMessage()
   ↓
3. Message saved to SwiftData (optimistic UI)
   ↓
4. UI updates immediately
   ↓
5. Background task uploads to Firestore
   ↓
6. Firestore listener on recipient's device triggers
   ↓
7. Recipient sees message in real-time
```

### Real-Time Update Flow

```
Firestore Change
   ↓
Listener Callback
   ↓
Service Layer
   ↓
@Published Property
   ↓
SwiftUI View Re-renders
```

### Offline-First Flow

```
User Action (Offline)
   ↓
Save to SwiftData
   ↓
Add to Sync Queue
   ↓
Network Monitor detects connection
   ↓
MessageSyncService uploads queued items
   ↓
Update local status to "sent"
```

---

## Service Layer

### Service Architecture

Each service is a **singleton** with a specific responsibility:

```swift
class AuthService {
    static let shared = AuthService()
    private init() {}  // Singleton pattern
    
    // Public API
    func signIn(...) async throws -> User
    func signOut() throws
    func getCurrentUser() async throws -> User?
}
```

### Key Services

#### 1. AuthService

**Purpose**: User authentication and management

```swift
// Sign up new user
let user = try await AuthService.shared.signUp(
    email: "user@example.com",
    password: "password",
    displayName: "John Doe"
)

// Sign in
let user = try await AuthService.shared.signIn(
    email: "user@example.com",
    password: "password"
)

// Get current user
let user = try await AuthService.shared.getCurrentUser()
```

#### 2. ConversationService

**Purpose**: Chat creation and management

```swift
// Find or create 1-on-1 conversation
let conversation = try await ConversationService.shared.findOrCreateConversation(
    currentUserID: currentUser.id,
    otherUserID: otherUser.id
)

// Create group chat
let group = try await ConversationService.shared.createGroupConversation(
    name: "Team Chat",
    participantIDs: [user1.id, user2.id, user3.id],
    creatorID: currentUser.id
)
```

#### 3. MediaService

**Purpose**: Image and voice message uploads

```swift
// Upload image
let imageURL = try await MediaService.shared.uploadImage(
    image: selectedImage,
    conversationID: conversation.id
)

// Upload voice message
let voiceURL = try await MediaService.shared.uploadVoiceMessage(
    audioURL: recordingURL,
    conversationID: conversation.id
)
```

#### 4. AIService

**Purpose**: Communication with Firebase Cloud Functions

```swift
// Generate summary
let summary = try await AIService.shared.summarizeThread(
    conversationID: conversation.id
)

// Extract action items
let actionItems = try await AIService.shared.extractActionItems(
    conversationID: conversation.id
)

// Detect priority
let priority = try await AIService.shared.detectPriority(
    messageText: "URGENT: Server is down!",
    conversationContext: recentMessages
)
```

#### 5. NetworkMonitor

**Purpose**: Real-time connectivity monitoring

```swift
class NetworkMonitor: ObservableObject {
    @Published var isConnected: Bool = true
    @Published var connectionType: ConnectionType = .wifi
    
    // Automatically monitors network status
    // Views can observe $isConnected
}
```

#### 6. PresenceService

**Purpose**: Online status with heartbeat mechanism

```swift
// Start presence updates (heartbeat every 15 seconds)
PresenceService.shared.startPresenceUpdates(
    userID: currentUser.id,
    showOnlineStatus: true
)

// Stop presence updates
PresenceService.shared.stopPresenceUpdates(userID: currentUser.id)
```

---

## Models

### User Model

```swift
@Model
class User: Identifiable, Codable {
    @Attribute(.unique) var id: String
    var email: String
    var displayName: String
    var profilePictureURL: String?
    var bio: String?
    var isOnline: Bool
    var lastSeen: Date?
    var lastHeartbeat: Date?  // For presence system
    var showOnlineStatus: Bool  // Privacy setting
    
    // Computed property for accurate online status
    var isActuallyOnline: Bool {
        guard showOnlineStatus, isOnline else { return false }
        guard let heartbeat = lastHeartbeat else { return false }
        return Date().timeIntervalSince(heartbeat) < 30  // 30 second threshold
    }
    
    // Firestore conversion
    func toDictionary() -> [String: Any]
    static func fromDictionary(_ dict: [String: Any]) -> User?
}
```

### Message Model

```swift
@Model
class Message: Identifiable, Codable {
    @Attribute(.unique) var id: String
    var conversationID: String
    var senderID: String
    var content: String
    var timestamp: Date
    var type: MessageType  // text, image, voice
    var mediaURL: String?
    var readBy: [String]  // User IDs who read this message
    var reactions: [String: String]  // userID: emoji
    var replyToMessageID: String?
    var deletedFor: [String]  // Soft delete for specific users
    var deletedForEveryone: Bool
    
    // Offline support
    var statusRaw: String  // pending, sending, sent, delivered, read
    var needsSync: Bool
    var syncAttempts: Int
    var lastSyncAttempt: Date?
    
    var status: MessageStatus {
        get { MessageStatus(rawValue: statusRaw) ?? .sent }
        set { statusRaw = newValue.rawValue }
    }
}

enum MessageStatus: String {
    case pending    // Queued locally
    case sending    // Upload in progress
    case sent       // Uploaded to Firestore
    case delivered  // Received by recipient
    case read       // Read by recipient
    case failed     // Upload failed
}
```

### Conversation Model

```swift
@Model
class Conversation: Identifiable, Codable {
    @Attribute(.unique) var id: String
    var isGroup: Bool
    var name: String?  // Group name
    var participantIDs: [String]
    var lastMessage: String?
    var lastMessageTime: Date?
    var lastSenderID: String?
    var lastMessageID: String?
    var unreadBy: [String]  // User IDs with unread messages
    var deletedBy: [String]  // Soft delete tracking
    var creatorID: String?
    
    // Computed property for unread indicator
    func hasUnreadMessages(for userID: String) -> Bool {
        return unreadBy.contains(userID)
    }
}
```

---

## Views

### View Hierarchy

```
RootView
├── MainTabView
│   ├── ConversationListView
│   │   └── ChatView
│   │       ├── MessageBubble
│   │       ├── VoiceMessageBubble
│   │       ├── ImageMessageBubble
│   │       └── AIFeaturesView
│   │           ├── AISummaryCard
│   │           ├── ActionItemsView
│   │           ├── DecisionsView
│   │           ├── SmartSearchView
│   │           └── PriorityDetectionView
│   ├── NewChatView
│   ├── NewGroupChatView
│   └── SettingsView
│       ├── PrivacySettingsView
│       └── AppearanceSettingsView
└── LoginView / SignUpView
```

### Key View Patterns

#### 1. ChatView (Complex View)

```swift
struct ChatView: View {
    @StateObject private var authViewModel: AuthViewModel
    @State private var messages: [Message] = []
    @State private var messageText = ""
    @State private var listener: ListenerRegistration?
    
    var body: some View {
        VStack {
            messagesView
            inputBar
        }
        .onAppear {
            startListening()
            Task { await markMessagesAsRead() }
        }
        .onDisappear {
            listener?.remove()
        }
    }
    
    private func startListening() {
        // Firestore real-time listener
    }
    
    private func sendMessage() {
        // Send message logic
    }
}
```

#### 2. Reusable Components

```swift
struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if !isCurrentUser {
                ProfileImageView(url: senderProfilePic, size: 32)
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading) {
                Text(message.content)
                    .padding()
                    .background(isCurrentUser ? Color.blue : Color.gray)
                    .cornerRadius(18)
                
                HStack {
                    Text(formattedTime)
                    if isCurrentUser {
                        MessageStatusIndicator(status: message.status)
                    }
                }
            }
        }
    }
}
```

---

## Real-Time Features

### Firestore Listeners

#### Message Listener

```swift
private func startListening() {
    listener = db.collection("conversations")
        .document(conversation.id)
        .collection("messages")
        .order(by: "timestamp", descending: false)
        .addSnapshotListener { snapshot, error in
            guard let snapshot = snapshot else { return }
            
            for change in snapshot.documentChanges {
                switch change.type {
                case .added:
                    // New message received
                    let message = Message.fromDictionary(change.document.data())
                    messages.append(message)
                    
                case .modified:
                    // Message updated (read receipt, reaction)
                    updateExistingMessage(change.document.data())
                    
                case .removed:
                    // Message deleted
                    messages.removeAll { $0.id == change.document.documentID }
                }
            }
        }
}
```

#### Typing Indicator

```swift
// Send typing indicator
func setTyping(isTyping: Bool) {
    db.collection("typing").document(conversation.id).setData([
        "users": [
            currentUser.id: [
                "isTyping": isTyping,
                "timestamp": FieldValue.serverTimestamp()
            ]
        ]
    ], merge: true)
}

// Listen for typing
func listenForTyping() {
    db.collection("typing").document(conversation.id)
        .addSnapshotListener { snapshot, error in
            // Update typing users list
        }
}
```

#### Presence System

```swift
// Heartbeat mechanism (every 15 seconds)
func startPresenceUpdates() {
    presenceTask = Task {
        while !Task.isCancelled {
            try? await setUserOnline(isOnline: true)
            try? await Task.sleep(nanoseconds: 15_000_000_000)  // 15 seconds
        }
    }
}

func setUserOnline(isOnline: Bool) async throws {
    try await db.collection("users").document(userID).updateData([
        "isOnline": isOnline,
        "lastHeartbeat": FieldValue.serverTimestamp(),
        "lastSeen": FieldValue.serverTimestamp()
    ])
}
```

---

## Offline-First Architecture

### Message Queue System

```swift
class MessageSyncService: ObservableObject {
    @Published var pendingMessages: [Message] = []
    
    // Add message to queue
    func queueMessage(_ message: Message) {
        message.status = .pending
        message.needsSync = true
        pendingMessages.append(message)
        saveToSwiftData(message)
    }
    
    // Sync when online
    func syncPendingMessages() async {
        for message in pendingMessages where message.needsSync {
            do {
                message.status = .sending
                try await uploadToFirestore(message)
                message.status = .sent
                message.needsSync = false
                message.syncAttempts = 0
            } catch {
                message.status = .failed
                message.syncAttempts += 1
                message.lastSyncAttempt = Date()
                
                // Exponential backoff
                if message.syncAttempts < 3 {
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(message.syncAttempts)) * 1_000_000_000))
                }
            }
        }
    }
}
```

### Network Monitoring Integration

```swift
struct ChatView: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        VStack {
            if !networkMonitor.isConnected {
                OfflineBanner()
            }
            messagesView
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            if isConnected {
                Task { await syncPendingMessages() }
            }
        }
    }
}
```

---

## AI Integration

### Firebase Cloud Functions Architecture

```
iOS App                Firebase Functions              OpenAI API
   │                          │                            │
   │  1. Call Function        │                            │
   ├──────────────────────────>│                            │
   │                          │  2. Fetch Messages         │
   │                          ├────────────>               │
   │                          │  Firestore                 │
   │                          │                            │
   │                          │  3. Format Prompt          │
   │                          │                            │
   │                          │  4. Call GPT-4             │
   │                          ├────────────────────────────>│
   │                          │                            │
   │                          │  5. Parse Response         │
   │                          │<────────────────────────────┤
   │                          │                            │
   │  6. Return Result        │                            │
   │<──────────────────────────┤                            │
```

### AI Service Implementation

```swift
class AIService {
    private let functions = Functions.functions()
    
    func summarizeThread(conversationID: String) async throws -> SummaryResult {
        let callable = functions.httpsCallable("summarizeThread")
        let result = try await callable.call(["conversationId": conversationID])
        
        guard let data = result.data as? [String: Any],
              let summary = data["summary"] as? String else {
            throw AIServiceError.parsingError
        }
        
        return SummaryResult(summary: summary, timestamp: Date())
    }
}
```

### Firebase Function (Node.js)

```javascript
exports.summarizeThread = functions.https.onCall(async (data, context) => {
  // 1. Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }
  
  // 2. Fetch messages from Firestore
  const messages = await fetchMessages(data.conversationId);
  
  // 3. Format prompt for GPT-4
  const prompt = formatMessagesForAI(messages);
  
  // 4. Call OpenAI API
  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  const completion = await openai.chat.completions.create({
    model: "gpt-4",
    messages: [
      { role: "system", content: SUMMARIZER_AGENT.instructions },
      { role: "user", content: prompt }
    ]
  });
  
  // 5. Return result
  return {
    summary: completion.choices[0].message.content,
    timestamp: new Date().toISOString()
  };
});
```

---

## Security

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users can read any user profile, but only write their own
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Conversations: only participants can access
    match /conversations/{conversationId} {
      allow read: if request.auth != null 
        && request.auth.uid in resource.data.participantIDs;
      allow create: if request.auth != null;
      allow update: if request.auth != null 
        && request.auth.uid in resource.data.participantIDs;
      
      // Messages: inherit conversation permissions
      match /messages/{messageId} {
        allow read, write: if request.auth != null 
          && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIDs;
      }
    }
  }
}
```

### Storage Security Rules

```javascript
service firebase.storage {
  match /b/{bucket}/o {
    
    // Profile pictures: users can only write their own
    match /profile_pictures/profile_{userId}.jpg {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Conversation media: participants only
    match /conversations/{conversationId}/{allPaths=**} {
      allow read, write: if request.auth != null;
      // Note: Conversation membership checked in app logic
    }
  }
}
```

---

## Performance Optimizations

### 1. Pagination

```swift
// Load messages in batches
func loadMoreMessages() async {
    let query = db.collection("conversations")
        .document(conversation.id)
        .collection("messages")
        .order(by: "timestamp", descending: true)
        .limit(to: 50)
        .start(afterDocument: lastDocument)
    
    let snapshot = try await query.getDocuments()
    // Process messages
}
```

### 2. Image Compression

```swift
func compressImage(_ image: UIImage) -> Data? {
    let maxSize: CGFloat = 1024  // 1024x1024 max
    let scale = min(maxSize / image.size.width, maxSize / image.size.height)
    
    let newSize = CGSize(
        width: image.size.width * scale,
        height: image.size.height * scale
    )
    
    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
    image.draw(in: CGRect(origin: .zero, size: newSize))
    let resized = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return resized?.jpegData(compressionQuality: 0.7)  // 70% quality
}
```

### 3. Listener Cleanup

```swift
class ChatView: View {
    @State private var listener: ListenerRegistration?
    
    var body: some View {
        // ...
        .onDisappear {
            listener?.remove()  // Always clean up listeners
            messages.removeAll()  // Clear local cache
        }
    }
}
```

---

## Testing Strategy

### Unit Tests

```swift
class AuthServiceTests: XCTestCase {
    func testSignUp() async throws {
        let user = try await AuthService.shared.signUp(
            email: "test@example.com",
            password: "password123",
            displayName: "Test User"
        )
        
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.displayName, "Test User")
    }
}
```

### Integration Tests

```swift
class MessageFlowTests: XCTestCase {
    func testSendAndReceiveMessage() async throws {
        // 1. Create conversation
        let conversation = try await ConversationService.shared.createConversation(...)
        
        // 2. Send message
        let message = Message(content: "Hello")
        try await sendMessage(message, to: conversation)
        
        // 3. Verify message received
        let messages = try await fetchMessages(from: conversation)
        XCTAssertEqual(messages.first?.content, "Hello")
    }
}
```

---

## Deployment

### Firebase Deployment

```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Storage rules
firebase deploy --only storage:rules

# Deploy Cloud Functions
cd functions
npm install
firebase deploy --only functions
```

### App Store Submission

1. Update version in Xcode
2. Archive build (Product → Archive)
3. Validate archive
4. Upload to App Store Connect
5. Submit for review

---

## Future Improvements

### Planned Features

1. **End-to-End Encryption**
   - Implement Signal Protocol
   - Encrypt messages before sending
   - Store encrypted locally

2. **Video Calls**
   - WebRTC integration
   - 1-on-1 and group calls
   - Screen sharing

3. **Message Translation**
   - Detect language
   - Translate in real-time
   - Support 100+ languages

4. **Advanced Search**
   - Full-text search with Algolia
   - Search by date, sender, media type
   - Search across all conversations

---

## Conclusion

MessageAI's architecture is designed for:

- **Scalability**: Easy to add new features
- **Maintainability**: Clear code organization
- **Performance**: Optimized for real-time updates
- **Reliability**: Offline-first with robust error handling
- **Security**: Firebase security rules and authentication

The combination of MVVM, service layer, and Firebase provides a solid foundation for a production-ready messaging application.

---

**Last Updated**: October 24, 2025  
**Version**: 1.0.0

