# MessageAI Technical Documentation

> Comprehensive technical guide for developers working on MessageAI

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Core Services](#core-services)
3. [AI Integration](#ai-integration)
4. [Data Flow](#data-flow)
5. [Firebase Integration](#firebase-integration)
6. [Offline Support](#offline-support)
7. [Security Implementation](#security-implementation)
8. [Performance Optimization](#performance-optimization)
9. [Error Handling](#error-handling)
10. [Testing Guidelines](#testing-guidelines)

---

## Architecture Overview

MessageAI follows a clean MVVM (Model-View-ViewModel) architecture with service-oriented business logic.

### Architecture Layers

```
┌─────────────────────────────────────┐
│         SwiftUI Views               │  ← User Interface
├─────────────────────────────────────┤
│         ViewModels                  │  ← State Management
├─────────────────────────────────────┤
│         Services                    │  ← Business Logic
├─────────────────────────────────────┤
│    Firebase SDK / OpenAI SDK        │  ← External APIs
├─────────────────────────────────────┤
│         SwiftData                   │  ← Local Persistence
└─────────────────────────────────────┘
```

### Design Patterns

1. **Singleton Services**: All services use shared instance pattern
2. **Dependency Injection**: Environment objects for cross-cutting concerns
3. **Observer Pattern**: Combine publishers for reactive updates
4. **Repository Pattern**: Services abstract data access
5. **Factory Pattern**: Model creation from dictionaries

---

## Core Services

### 1. AuthService

**Purpose**: Manages user authentication and user data fetching.

**Key Methods**:
```swift
func signUp(email: String, password: String, displayName: String) async throws -> User
func signIn(email: String, password: String) async throws -> User
func signOut() throws
func fetchUserDocument(userId: String) async throws -> User
func findUserByEmail(email: String) async throws -> User?
func fetchAllUsers() async throws -> [User]
```

**Implementation Details**:
- Uses Firebase Authentication for user management
- Creates Firestore user document on signup
- Fetches and caches user data
- Handles email/password validation

**Error Handling**:
- Invalid credentials → Throws descriptive error
- Network errors → Propagated to UI layer
- User not found → Returns nil (for optional cases)

### 2. ConversationService

**Purpose**: Creates and manages conversations (1-on-1 and groups).

**Key Methods**:
```swift
func findOrCreateConversation(
    currentUserID: String,
    otherUserID: String,
    modelContext: ModelContext
) async throws -> Conversation
```

**Flow**:
1. Check if conversation already exists between users
2. If exists, return it
3. If not, create new conversation in Firestore
4. Save to local SwiftData
5. Return Conversation object

**Deduplication Logic**:
```swift
// For 1-on-1 chats, check both participant orders
participantIDs == [userA, userB] OR participantIDs == [userB, userA]
```

### 3. MediaService

**Purpose**: Handles image and voice file uploads to Firebase Storage.

**Key Methods**:
```swift
func uploadImage(_ image: UIImage, conversationID: String) async throws -> String
func uploadProfilePicture(_ image: UIImage, userID: String) async throws -> String
func uploadGroupPicture(_ image: UIImage, groupID: String) async throws -> String
func deleteProfilePicture(userID: String) async throws
```

**Image Processing**:
1. **Resize**: Scale down to max dimensions
   - Conversation images: 1024x1024
   - Profile pictures: 800x800
   - Group pictures: 800x800
2. **Compress**: JPEG quality 60-70%
3. **Upload**: Firebase Storage with metadata
4. **Return**: Download URL for Firestore

**Storage Paths**:
- Profiles: `profile_pictures/profile_{userId}.jpg`
- Groups: `group_pictures/group_{groupId}.jpg`
- Messages: `conversations/{convId}/{uuid}.jpg`
- Voice: `voice/{userId}_{timestamp}.m4a`

### 4. PresenceService

**Purpose**: Manages real-time user online/offline status.

**How It Works**:
```swift
// Start continuous heartbeat
func startPresenceUpdates(userID: String, showOnlineStatus: Bool)

// Heartbeat loop (every 15 seconds)
while !Task.isCancelled {
    updateData = [
        "isOnline": showOnlineStatus && isOnline,
        "lastHeartbeat": FieldValue.serverTimestamp()
    ]
    
    await db.collection("users").document(userID).updateData(updateData)
    try await Task.sleep(nanoseconds: 15_000_000_000)
}
```

**Online Detection**:
```swift
var isActuallyOnline: Bool {
    guard showOnlineStatus, isOnline, let heartbeat = lastHeartbeat else {
        return false
    }
    let timeSinceHeartbeat = Date().timeIntervalSince(heartbeat)
    return timeSinceHeartbeat < 20  // 20 second threshold
}
```

**Network Monitoring**:
- Observes `NetworkMonitor.shared.$isConnected`
- Pauses heartbeat when offline
- Resumes automatically when connection restored
- Prevents failed writes and battery drain

### 5. BlockUserService

**Purpose**: Handles user blocking and reporting.

**Block Flow**:
```swift
func blockUser(blockerID: String, blockedID: String, conversationID: String?) async throws {
    // 1. Add to blockedUsers array
    await db.collection("users").document(blockerID).updateData([
        "blockedUsers": FieldValue.arrayUnion([blockedID])
    ])
    
    // 2. Remove from contacts
    await db.collection("users").document(blockerID).updateData([
        "contacts": FieldValue.arrayRemove([blockedID])
    ])
    
    // 3. Delete conversation
    if let conversationID {
        await db.collection("conversations").document(conversationID).delete()
    }
}
```

**Firebase Function - Auto-Reply**:
```javascript
// Trigger on message creation
exports.checkBlockOnMessage = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const senderID = message.senderID;
    
    // Check if sender is blocked
    const recipientDoc = await getRecipient(conversationId);
    const blockedUsers = recipientDoc.data()?.blockedUsers || [];
    
    if (blockedUsers.includes(senderID)) {
        // Delete their message
        await snap.ref.delete();
        
        // Send auto-reply
        await sendSystemMessage(conversationId, "This user has blocked you");
    }
  });
```

### 6. MessageSyncService

**Purpose**: Handles offline message queue and background sync.

**Queue Architecture**:
```swift
class MessageSyncService {
    // Track pending messages
    @Published var pendingMessageCount: Int = 0
    @Published var isSyncing: Bool = false
    
    // Queue message for sending
    func queueMessage(
        _ message: Message,
        conversationID: String,
        currentUserID: String,
        modelContext: ModelContext
    ) async throws {
        // 1. Save to SwiftData immediately
        message.status = networkMonitor.isConnected ? .sending : .pending
        modelContext.insert(message)
        
        // 2. If online, send now
        if networkMonitor.isConnected {
            try await sendMessage(message, conversationID: conversationID)
        }
        // If offline, will auto-sync when network returns
    }
}
```

**Sync Strategy**:
1. **Optimistic UI**: Message appears instantly
2. **Background Queue**: Pending messages tracked
3. **Network Observer**: Auto-sync on reconnection
4. **Exponential Backoff**: Retry with increasing delays
5. **Max Retries**: Give up after 3 attempts

### 7. TypingIndicatorService

**Purpose**: Real-time typing status for active conversations.

**Protocol**:
```swift
// Start typing
func startTyping(conversationID: String, userID: String) async {
    await db.collection("conversations").document(conversationID).updateData([
        "typingUsers": FieldValue.arrayUnion([userID])
    ])
    
    // Auto-clear after 3 seconds
    Task {
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        await stopTyping(conversationID: conversationID, userID: userID)
    }
}

// Stop typing
func stopTyping(conversationID: String, userID: String) async {
    await db.collection("conversations").document(conversationID).updateData([
        "typingUsers": FieldValue.arrayRemove([userID])
    ])
}
```

**UI Integration**:
- Triggered on text field edit
- Cleared on send or focus loss
- Shows "User is typing..." in ChatView
- Supports multiple users in groups

---

## AI Integration

### AIService Architecture

**Service Layer**:
```swift
@MainActor
class AIService {
    static let shared = AIService()
    private let functions = Functions.functions()
    private let maxRetries = 3
    
    func summarizeThread(conversationID: String, messageLimit: Int) async throws -> ConversationSummary
    func extractActionItems(conversationID: String) async throws -> ActionItemsResult
    func trackDecisions(conversationID: String) async throws -> DecisionsResult
    func smartSearch(conversationID: String, query: String) async throws -> SmartSearchResults
    func detectPriority(messageText: String) async throws -> PriorityResult
}
```

### Firebase Cloud Functions

**Function Template**:
```javascript
exports.functionName = functions.https.onCall(async (data, context) => {
  // 1. Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }
  
  // 2. Validate input
  const { conversationId, ...params } = data;
  if (!conversationId) {
    throw new functions.https.HttpsError('invalid-argument', 'conversationId required');
  }
  
  // 3. Fetch messages
  const messages = await getConversationMessages(conversationId, limit);
  
  // 4. Format for AI
  const conversationText = formatMessagesForAI(messages, { includeMetadata: true });
  
  // 5. Call OpenAI
  const responseText = await callAgent(AGENT, prompt, {
    temperature: 0.2,
    maxTokens: 4096,
    jsonMode: true
  });
  
  // 6. Parse response
  const parsed = extractJSON(responseText);
  
  // 7. Clean Unicode
  const sanitized = cleanInvalidUnicode(parsed);
  
  // 8. Return to client
  return sanitized;
});
```

### Agent Configuration

**Agent Definition Pattern**:
```javascript
const AGENT_NAME = {
  name: "AgentName",
  model: "gpt-4-turbo-preview",  // Fast and cost-effective
  instructions: `
    You are an expert in [domain].
    
    CORE MISSION: [Clear purpose statement]
    
    INPUT: [What you'll receive]
    
    OUTPUT: [Exact JSON format required]
    
    RULES:
    1. [Specific behavior rules]
    2. [Edge cases to handle]
    3. [Quality standards]
    
    IMPORTANT: [Critical reminders]
  `
};
```

### Error Recovery

**Retry Logic**:
```swift
private func executeWithRetry<T>(
    functionName: String,
    operation: () async throws -> T
) async throws -> T {
    var lastError: Error?
    
    for attempt in 1...maxRetries {
        do {
            return try await operation()
        } catch {
            lastError = error
            
            // Check if retryable
            if !isRetryableError(error) {
                throw parseFirebaseError(error, functionName: functionName)
            }
            
            // Exponential backoff
            if attempt < maxRetries {
                let delay = baseRetryDelay * pow(2.0, Double(attempt - 1))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
    
    throw AIServiceError.retryLimitExceeded
}
```

**Retryable Errors**:
- Network timeouts
- Connection failures
- Server errors (5xx)
- Unavailable/deadline exceeded

**Non-Retryable Errors**:
- Authentication failures
- Invalid arguments
- Function not found
- Permission denied
- Parsing errors

### Unicode Handling

**Problem**: AI responses sometimes contain invalid Unicode surrogate pairs that break JSON parsing.

**Solution**:
```javascript
function sanitizeString(str) {
  if (typeof str !== 'string') return str;
  
  // Remove control characters
  let cleaned = str.replace(/[\u0000-\u001F\u007F-\u009F]/g, '');
  
  // Remove invalid surrogate pairs (e.g., \udccb, \udea7)
  cleaned = cleaned.replace(/[\uD800-\uDFFF]/g, '');
  
  return cleaned;
}

function sanitizeForJSON(obj) {
  if (typeof obj === 'string') return sanitizeString(obj);
  if (Array.isArray(obj)) return obj.map(sanitizeForJSON);
  if (typeof obj === 'object' && obj !== null) {
    const sanitized = {};
    for (const key in obj) {
      sanitized[key] = sanitizeForJSON(obj[key]);
    }
    return sanitized;
  }
  return obj;
}
```

**Applied To**:
- All summary points
- Action item descriptions
- Decision text
- Search results
- Any user-generated content processed by AI

---

## Data Flow

### Message Sending Flow

```
User Types Message
        ↓
    Send Button
        ↓
Create Message Object (status: .pending)
        ↓
Save to SwiftData (local first)
        ↓
    Online? ──No──→ Queue for Later
        ↓ Yes              ↓
Upload to Firestore    Sync on Reconnect
        ↓
Update Conversation LastMessage
        ↓
Firestore Snapshot Listener Triggers
        ↓
Update UI (status: .sent → .delivered → .read)
```

### Message Receiving Flow

```
Firestore Snapshot Listener
        ↓
Document Change Detected
        ↓
Parse Message Data
        ↓
Convert Timestamps
        ↓
Check if Already Exists
        ↓ No
Add to Messages Array
        ↓
Save to SwiftData
        ↓
Trigger UI Update
        ↓
Show Notification (if not in chat)
        ↓
Mark as Read (if in chat)
```

### AI Feature Flow

```
User Clicks AI Feature Button
        ↓
Show Loading State
        ↓
Call AIService Method
        ↓
AIService → Firebase Functions (HTTPS Callable)
        ↓
Firebase Function:
  1. Validate Auth
  2. Fetch Messages from Firestore
  3. Format for AI
  4. Call OpenAI API
  5. Parse JSON Response
  6. Clean Unicode
  7. Return to Client
        ↓
Swift Parses Response
        ↓
Update UI with Results
```

### Presence Update Flow

```
App Enters Foreground
        ↓
Start Presence Updates
        ↓
Every 15 Seconds:
  ├─ Check Network Status
  ├─ If Online:
  │   └─ Update Firestore:
  │       • isOnline: true
  │       • lastHeartbeat: serverTimestamp
  └─ If Offline:
      └─ Pause Updates
        ↓
Other Users' Listeners Receive Update
        ↓
Check: (Date.now - lastHeartbeat) < 20s?
  ├─ Yes → Show as Online
  └─ No → Show as Offline
```

---

## Firebase Integration

### Firestore Listeners

**Pattern**: All real-time data uses snapshot listeners.

**ChatView Messages Listener**:
```swift
listener = db.collection("conversations")
    .document(conversationID)
    .collection("messages")
    .order(by: "timestamp", descending: false)
    .addSnapshotListener { snapshot, error in
        guard let snapshot = snapshot else { return }
        
        let isInitialLoad = self.messages.isEmpty
        
        if isInitialLoad {
            // Process ALL documents on first load
            for document in snapshot.documents {
                let message = parseMessage(document.data())
                messages.append(message)
            }
        } else {
            // Process only changes on updates
            for change in snapshot.documentChanges {
                switch change.type {
                case .added: messages.append(parseMessage(change.document.data()))
                case .modified: updateMessage(parseMessage(change.document.data()))
                case .removed: removeMessage(change.document.id)
                }
            }
        }
    }
```

**Why Two Paths?**
- **Initial Load**: Firestore sometimes returns only recent changes, not all documents
- **Solution**: On first load, process `snapshot.documents` to get everything
- **Updates**: Use `snapshot.documentChanges` for efficient delta updates

**ConversationList Listener**:
```swift
listener = db.collection("conversations")
    .whereField("participantIDs", arrayContains: currentUserID)
    .order(by: "lastMessageTime", descending: true)
    .addSnapshotListener { snapshot, error in
        // Convert Timestamp to Date for each conversation
        for document in snapshot.documents {
            var data = document.data()
            if let timestamp = data["lastMessageTime"] as? Timestamp {
                data["lastMessageTime"] = timestamp.dateValue()
            }
            let conversation = Conversation.fromDictionary(data)
            conversations.append(conversation)
        }
    }
```

**Presence Listener** (ChatView):
```swift
presenceListener = db.collection("users")
    .document(otherUserID)
    .addSnapshotListener { snapshot, error in
        guard let data = snapshot?.data() else { return }
        
        let isOnline = data["isOnline"] as? Bool ?? false
        let showOnlineStatus = data["showOnlineStatus"] as? Bool ?? true
        
        // Update UI
        otherUser.isOnline = isOnline
        otherUser.showOnlineStatus = showOnlineStatus
    }
```

### Timestamp Handling

**Critical**: Firestore Timestamps must be converted to Swift Dates.

**Wrong**:
```swift
let lastSeen = data["lastSeen"] as? Date  // ❌ Returns nil!
```

**Correct**:
```swift
var lastSeen: Date?
if let timestamp = data["lastSeen"] as? Timestamp {
    lastSeen = timestamp.dateValue()  // ✅ Converts properly
} else if let date = data["lastSeen"] as? Date {
    lastSeen = date  // Fallback for local data
}
```

**When Writing**:
```swift
messageData["timestamp"] = Timestamp(date: message.timestamp)
```

**When Reading**:
```swift
if let timestamp = data["timestamp"] as? Timestamp {
    data["timestamp"] = timestamp.dateValue()
}
let message = Message.fromDictionary(data)
```

### Batch Operations

**Use batched writes for atomic operations**:

```swift
let batch = db.batch()

for message in messages {
    let ref = db.collection("conversations")
        .document(conversationID)
        .collection("messages")
        .document(message.id)
    
    batch.setData(message.toDictionary(), forDocument: ref)
}

try await batch.commit()  // All or nothing
```

**Benefits**:
- Atomic: All succeed or all fail
- Performance: Single network round-trip
- Consistency: No partial states

---

## Offline Support

### SwiftData Integration

**Purpose**: Local cache for offline access and performance.

**Model Persistence**:
```swift
// Define persistent models
@Model
class Message: Identifiable {
    var id: String
    var content: String
    var needsSync: Bool = false
    var syncAttempts: Int = 0
}

// Set up model container in App
.modelContainer(for: [User.self, Conversation.self, Message.self])
```

**Sync Flow**:
```swift
// When network restored
NetworkMonitor.shared.$isConnected
    .sink { isConnected in
        if isConnected {
            Task {
                await MessageSyncService.shared.syncPendingMessages()
            }
        }
    }
```

### Message Status States

```swift
enum MessageStatus: String {
    case pending    // Queued locally (offline)
    case sending    // Upload in progress
    case sent       // Uploaded to Firestore
    case delivered  // Received by recipient device
    case read       // Viewed by recipient
    case failed     // Upload failed after retries
}
```

**Status Progression**:
```
pending → sending → sent → delivered → read
   ↓
 failed (after 3 retries)
```

### Optimistic Updates

**Problem**: Don't want listener updates to overwrite optimistic UI changes.

**Solution**: Track recently updated messages:
```swift
// Global tracking (survives view recreations)
private static var globalRecentlyUpdatedMessages: [String: Date] = [:]

// Before optimistic update
ChatView.globalRecentlyUpdatedMessages[messageID] = Date()

// In listener
let isRecentlyUpdated = 
    ChatView.globalRecentlyUpdatedMessages[messageID] != nil &&
    Date().timeIntervalSince(ChatView.globalRecentlyUpdatedMessages[messageID]!) < 10

if isRecentlyUpdated {
    continue  // Skip listener update
}
```

**Cleanup**: Old entries automatically expire after 10 seconds.

---

## Security Implementation

### Authentication Flow

```swift
// Sign Up
1. Create Firebase Auth user
2. Create Firestore user document
3. Set initial presence (online)
4. Return User object

// Sign In
1. Authenticate with Firebase
2. Fetch user document from Firestore
3. Start presence updates
4. Load contacts
5. Return User object

// Sign Out
1. Stop presence updates
2. Set isOnline: false
3. Clear local cache
4. Sign out from Firebase Auth
```

### Data Validation

**Client-Side**:
```swift
// Email validation
let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
guard emailPredicate.evaluate(with: email) else {
    throw ValidationError.invalidEmail
}

// Password validation
guard password.count >= 6 else {
    throw ValidationError.passwordTooShort
}
```

**Server-Side** (Firestore Rules):
```javascript
// Only conversation participants can read/write
allow read, write: if request.auth.uid in resource.data.participantIDs;

// Only message sender can delete
allow delete: if request.auth.uid == resource.data.senderID;
```

### Input Sanitization

**For AI Inputs**:
```javascript
function sanitizeInput(text) {
    // Remove dangerous characters
    return text
        .replace(/[<>]/g, '')  // Remove HTML tags
        .trim()
        .substring(0, 10000);  // Limit length
}
```

**For User Data**:
```swift
let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
guard !trimmedName.isEmpty else {
    throw ValidationError.emptyName
}
```

---

## Performance Optimization

### Image Handling

**Resizing Algorithm**:
```swift
func resized(to targetSize: CGSize) -> UIImage {
    let size = self.size
    
    // Maintain aspect ratio
    let widthRatio = targetSize.width / size.width
    let heightRatio = targetSize.height / size.height
    let ratio = min(widthRatio, heightRatio)
    
    let newSize = CGSize(
        width: size.width * ratio,
        height: size.height * ratio
    )
    
    // Render at scale 1.0 (not @2x or @3x)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    
    return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
        self.draw(in: CGRect(origin: .zero, size: newSize))
    }
}
```

**Compression**:
```swift
// Balance quality vs. size
let imageData = resizedImage.jpegData(compressionQuality: 0.7)
```

### Memory Management

**Listener Cleanup**:
```swift
.onDisappear {
    // Always remove listeners to prevent leaks
    listener?.remove()
    typingListener?.remove()
    presenceListener?.remove()
    
    // Cancel tasks
    presenceTask?.cancel()
}
```

**Task Cancellation**:
```swift
presenceTask = Task {
    while !Task.isCancelled {
        await updatePresence()
        try? await Task.sleep(nanoseconds: 15_000_000_000)
    }
}

// Cancel when no longer needed
presenceTask?.cancel()
presenceTask = nil
```

### Caching Strategy

**User Cache** (ConversationListView):
```swift
@State private var userCache: [String: User] = [:]

// Fetch once, reuse everywhere
for participantID in conversation.participantIDs {
    if userCache[participantID] == nil {
        let user = try await fetchUser(participantID)
        userCache[participantID] = user
    }
}
```

**Benefits**:
- Reduces Firestore reads
- Faster UI rendering
- Lower costs
- Better offline experience

---

## Error Handling

### Error Hierarchy

```swift
// AI Service Errors
enum AIServiceError: LocalizedError {
    case invalidResponse
    case networkError(Error)
    case parsingError
    case unauthenticated
    case functionNotFound(String)
    case permissionDenied
    case timeout
    case retryLimitExceeded
    
    var errorDescription: String? { ... }
    var recoverySuggestion: String? { ... }
}
```

### Error Presentation

**User-Friendly Messages**:
```swift
// Bad
"Error: NSCocoaErrorDomain Code 3840"

// Good
"Failed to load summary. Please check your connection and try again."
```

**With Recovery**:
```swift
if let suggestion = error.recoverySuggestion {
    errorMessage += "\n\n\(suggestion)"
}
```

### Logging Best Practices

**Structured Logging**:
```swift
print("🚀 ChatView: Starting chat with \(email)")
print("📧 Looking up user by email...")
print("✅ Found user: \(user.displayName)")
print("❌ Error: \(error.localizedDescription)")
```

**Log Levels**:
- 🚀 Action started
- 📤 Request sent
- 📥 Response received
- ✅ Success
- ❌ Error
- ⚠️ Warning
- ℹ️ Info

---

## Testing Guidelines

### Unit Testing (Future)

**Services to Test**:
```swift
class AuthServiceTests: XCTestCase {
    func testSignUpCreatesUser() async throws
    func testSignInWithValidCredentials() async throws
    func testSignInWithInvalidCredentials() async throws
    func testFetchUserDocument() async throws
}

class ConversationServiceTests: XCTestCase {
    func testFindOrCreateConversation() async throws
    func testDeduplicationLogic() async throws
}
```

### Integration Testing

**Test Scenarios**:
1. **Full Message Flow**: Send → Receive → Read → Delete
2. **Offline → Online**: Queue → Sync → Verify
3. **Group Operations**: Create → Add/Remove → Delete
4. **AI Features**: Call each function with real data
5. **Block Flow**: Block → Auto-reply → Verify isolation

### UI Testing

**Critical Paths**:
```swift
func testSendMessageFlow() {
    app.textFields["Message"].tap()
    app.textFields["Message"].typeText("Hello")
    app.buttons["Send"].tap()
    
    XCTAssertTrue(app.staticTexts["Hello"].exists)
}
```

---

## Advanced Topics

### Custom Components

#### ProfileImageView

**Features**:
- Async image loading
- Fallback to initials
- Customizable size
- Circular clipping
- Loading states

**Usage**:
```swift
ProfileImageView(
    url: user.profilePictureURL,
    size: 56,
    fallbackText: user.displayName
)
```

**Implementation**:
```swift
if let url = URL(string: urlString) {
    AsyncImage(url: url) { phase in
        switch phase {
        case .success(let image):
            image.resizable().scaledToFill()
        case .failure, .empty:
            fallbackView
        }
    }
} else {
    fallbackView
}
```

### Network Monitoring

**NetworkMonitor Singleton**:
```swift
class NetworkMonitor: ObservableObject {
    @Published var isConnected: Bool = true
    
    private let monitor = NWPathMonitor()
    
    init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue.global())
    }
}
```

**Usage**:
```swift
@StateObject private var networkMonitor = NetworkMonitor.shared

if !networkMonitor.isConnected {
    OfflineIndicatorView()
}
```

### Theme Management

**ThemeManager**:
```swift
class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .system
    
    var currentColorScheme: ColorScheme? {
        switch currentTheme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}
```

**Apply Theme**:
```swift
.preferredColorScheme(themeManager.currentColorScheme)
```

---

## Deployment Checklist

### Pre-Deployment

- [ ] Update version number in Info.plist
- [ ] Test on real device (not just simulator)
- [ ] Verify all AI functions deployed
- [ ] Check Firestore security rules
- [ ] Verify Storage rules
- [ ] Test offline functionality
- [ ] Check memory leaks with Instruments
- [ ] Verify no API keys in code
- [ ] Update documentation
- [ ] Create release notes

### Firebase Functions

```bash
# Test locally (optional)
firebase emulators:start

# Deploy to production
firebase deploy --only functions

# Verify deployment
firebase functions:log
```

### iOS App

```bash
# Archive
xcodebuild archive -scheme MessageAI -archivePath build/MessageAI.xcarchive

# Export IPA
xcodebuild -exportArchive -archivePath build/MessageAI.xcarchive -exportPath build/

# Upload to App Store Connect
# (Use Xcode or Transporter app)
```

---

## Monitoring & Maintenance

### Firebase Console

**Monitor**:
1. **Authentication**: Daily active users, sign-ups
2. **Firestore**: Read/write operations, storage size
3. **Storage**: File uploads, storage usage
4. **Functions**: Invocations, errors, execution time

**Alerts**:
- Set up budget alerts for unexpected costs
- Monitor function error rates
- Track slow queries
- Watch for spam/abuse

### OpenAI Usage

**Track Costs**:
- Monitor token usage in OpenAI dashboard
- Set monthly spending limits
- Alert on unusual spikes
- Optimize prompts for efficiency

**Cost Optimization**:
- Cache summaries (not currently implemented)
- Limit message count for AI analysis
- Use smaller models for simple tasks
- Batch operations when possible

### Error Monitoring

**Firebase Crashlytics** (not yet implemented):
```swift
import FirebaseCrashlytics

// Log non-fatal errors
Crashlytics.crashlytics().record(error: error)

// Custom keys for context
Crashlytics.crashlytics().setCustomValue(userID, forKey: "user_id")
```

---

## Best Practices

### Swift Concurrency

**Always use @MainActor for UI updates**:
```swift
await MainActor.run {
    self.messages.append(newMessage)
}
```

**Structured Concurrency**:
```swift
// Task groups for parallel operations
await withTaskGroup(of: User?.self) { group in
    for userID in userIDs {
        group.addTask {
            try? await fetchUser(userID)
        }
    }
    
    for await user in group {
        if let user { users.append(user) }
    }
}
```

### Memory Safety

**Weak Self in Closures**:
```swift
networkCancellable = NetworkMonitor.shared.$isConnected
    .sink { [weak self] isConnected in
        guard let self = self else { return }
        Task { await self.handleConnectionChange(isConnected) }
    }
```

**Cancel Tasks on Dismiss**:
```swift
.onDisappear {
    task?.cancel()
}
```

### Code Organization

**MARK Comments**:
```swift
// MARK: - Lifecycle
// MARK: - UI Components
// MARK: - Data Loading
// MARK: - Actions
// MARK: - Helpers
```

**File Structure**:
- One view per file
- Related components in same file
- Services in dedicated files
- Models in separate folder

---

## FAQ

### Why SwiftData over Core Data?

- Modern Swift-first API
- Less boilerplate
- Better Combine integration
- Automatic iCloud sync (future)
- Type-safe queries

### Why Firebase over custom backend?

- Real-time capabilities out of the box
- Scalable without DevOps
- Built-in authentication
- Generous free tier
- Global CDN for media

### Why GPT-4 Turbo over other models?

- Best balance of speed and quality
- 4096 token output (vs 2048 for base)
- Lower cost than GPT-4
- JSON mode support
- Better instruction following

### Can I use a different AI provider?

Yes! The AIService is abstracted. To switch:
1. Update `callAgent` in functions/index.js
2. Replace OpenAI client with alternative
3. Adjust prompt formats if needed
4. Update response parsing

---

## Troubleshooting Advanced Issues

### Firestore Permission Denied

**Symptom**: "Permission denied" when accessing data

**Debug**:
```javascript
// Enable verbose logging
db.setLogLevel('debug');
```

**Common Causes**:
1. Security rules too restrictive
2. User not in participantIDs array
3. Trying to access another user's data

**Fix**: Review and update security rules

### Memory Leaks

**Detect**:
- Use Xcode Instruments
- Memory Graph Debugger
- Monitor memory usage over time

**Common Sources**:
- Firestore listeners not removed
- Strong reference cycles
- Tasks not cancelled
- Images not released

**Fix**:
```swift
// Weak self
.sink { [weak self] in ... }

// Remove listeners
listener?.remove()

// Cancel tasks
task?.cancel()
```

### AI Response Parsing Failures

**Symptom**: "Parsing error" despite valid JSON

**Causes**:
1. Invalid Unicode characters
2. Truncated responses (token limit)
3. Markdown code blocks in response
4. Extra text before/after JSON

**Solutions**:
```javascript
// 1. Clean Unicode
const cleaned = removeInvalidUnicode(text);

// 2. Increase tokens
maxTokens: 4096  // Maximum

// 3. Extract JSON from markdown
const jsonMatch = text.match(/\{[\s\S]*\}/);

// 4. Enable JSON mode
jsonMode: true
```

---

## Performance Profiling

### Key Metrics to Monitor

1. **App Launch Time**: < 2s cold start
2. **Message Send Latency**: < 500ms
3. **AI Response Time**: < 15s
4. **Memory Usage**: < 150MB active
5. **Battery Drain**: < 5% per hour active use

### Instruments

**Use these instruments**:
- **Time Profiler**: Find slow functions
- **Allocations**: Track memory usage
- **Leaks**: Detect memory leaks
- **Network**: Monitor bandwidth
- **Energy Log**: Battery impact

---

## Conclusion

MessageAI demonstrates modern iOS development with:
- SwiftUI for reactive, declarative UI
- Firebase for scalable real-time backend
- AI integration for intelligent features
- Clean architecture for maintainability
- Offline-first for reliability

The codebase is structured for growth, with clear separation of concerns and extensive documentation.

For questions or contributions, please open an issue or pull request on GitHub.

---

*Built with 🤖 and ☕ by Akhil Pinnani*

