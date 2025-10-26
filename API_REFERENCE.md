# MessageAI API Reference

Complete reference for all services, methods, and Firebase Cloud Functions.

---

## Table of Contents

1. [Services API](#services-api)
2. [Firebase Cloud Functions](#firebase-cloud-functions)
3. [Models Reference](#models-reference)
4. [ViewModels](#viewmodels)
5. [Utilities](#utilities)

---

## Services API

### AuthService

#### `signUp(email:password:displayName:)`

Creates a new user account.

**Parameters**:
- `email: String` - User's email address
- `password: String` - Password (min 6 characters)
- `displayName: String` - User's display name

**Returns**: `User` - Created user object

**Throws**:
- `NSError` - Firebase Auth errors
- Email already in use
- Weak password
- Invalid email format

**Example**:
```swift
do {
    let user = try await AuthService.shared.signUp(
        email: "user@example.com",
        password: "password123",
        displayName: "John Doe"
    )
    print("User created: \(user.id)")
} catch {
    print("Signup failed: \(error.localizedDescription)")
}
```

#### `signIn(email:password:)`

Authenticates existing user.

**Parameters**:
- `email: String` - User's email
- `password: String` - User's password

**Returns**: `User` - Authenticated user

**Throws**:
- Invalid credentials
- User not found
- Network errors

#### `findUserByEmail(email:)`

Searches for user by email address.

**Parameters**:
- `email: String` - Email to search for

**Returns**: `User?` - Found user or nil

**Use Cases**:
- Starting new chats
- Adding contacts
- User search

---

### ConversationService

#### `findOrCreateConversation(currentUserID:otherUserID:modelContext:)`

Finds existing 1-on-1 conversation or creates new one.

**Parameters**:
- `currentUserID: String` - Current user's ID
- `otherUserID: String` - Other participant's ID
- `modelContext: ModelContext` - SwiftData context

**Returns**: `Conversation` - Existing or newly created conversation

**Throws**: Firestore errors

**Logic**:
```swift
// Checks both orderings for existing conversation
let existingConversations = try await db
    .collection("conversations")
    .whereField("isGroup", isEqualTo: false)
    .whereField("participantIDs", arrayContains: currentUserID)
    .getDocuments()

for doc in existingConversations {
    let participantIDs = doc.data()["participantIDs"] as? [String]
    if participantIDs?.contains(otherUserID) == true {
        return Conversation.fromDictionary(doc.data())
    }
}

// Not found - create new
return try await createConversation(...)
```

---

### MediaService

#### `uploadImage(_:conversationID:)`

Uploads image to Firebase Storage.

**Parameters**:
- `image: UIImage` - Image to upload
- `conversationID: String` - Conversation ID for path

**Returns**: `String` - Download URL

**Processing**:
1. Resize to max 1024x1024
2. Convert to JPEG (70% quality)
3. Upload to `conversations/{id}/{uuid}.jpg`
4. Return download URL

**Throws**:
- Image conversion errors
- Upload failures
- Network timeouts

#### `uploadProfilePicture(_:userID:)`

Uploads user profile picture.

**Parameters**:
- `image: UIImage` - Profile picture
- `userID: String` - User's ID

**Returns**: `String` - Download URL

**Path**: `profile_pictures/profile_{userId}.jpg`

**Note**: Overwrites existing profile picture

#### `uploadGroupPicture(_:groupID:)`

Uploads group chat picture.

**Parameters**:
- `image: UIImage` - Group picture
- `groupID: String` - Group conversation ID

**Returns**: `String` - Download URL

**Path**: `group_pictures/group_{groupId}.jpg`

#### `deleteProfilePicture(userID:)`

Deletes user's profile picture from Storage.

**Parameters**:
- `userID: String` - User's ID

**Throws**: Storage deletion errors

---

### PresenceService

#### `startPresenceUpdates(userID:showOnlineStatus:)`

Begins continuous presence heartbeat.

**Parameters**:
- `userID: String` - User's ID
- `showOnlineStatus: Bool` - Privacy setting

**Behavior**:
- Updates every 15 seconds
- Writes `isOnline` and `lastHeartbeat` to Firestore
- Automatically pauses when offline
- Resumes when network restored

**Network Awareness**:
```swift
NetworkMonitor.shared.$isConnected
    .sink { isConnected in
        if isConnected {
            startPresenceUpdates(...)
        } else {
            presenceTask?.cancel()
        }
    }
```

#### `stopPresenceUpdates(userID:)`

Stops heartbeat and sets user offline.

**Parameters**:
- `userID: String` - User's ID

**Actions**:
1. Cancels heartbeat task
2. Sets `isOnline: false`
3. Updates `lastSeen` to current time

#### `setUserOnline(userID:isOnline:showOnlineStatus:)`

Manually updates user's online status.

**Parameters**:
- `userID: String`
- `isOnline: Bool`
- `showOnlineStatus: Bool`

**Use Cases**:
- App foreground/background transitions
- Manual status updates
- Privacy changes

---

### BlockUserService

#### `blockUser(blockerID:blockedID:conversationID:)`

Blocks a user and cleans up related data.

**Parameters**:
- `blockerID: String` - User doing the blocking
- `blockedID: String` - User being blocked
- `conversationID: String?` - Conversation to delete

**Actions**:
1. Adds to `blockedUsers` array
2. Removes from `contacts` array
3. Deletes conversation (if provided)
4. Triggers Firebase Function for auto-replies

**Side Effects**:
- Blocked user gets "This user has blocked you" message
- All future messages from blocked user auto-deleted
- Conversations no longer visible

#### `unblockUser(blockerID:blockedID:)`

Removes user from block list.

**Parameters**:
- `blockerID: String`
- `blockedID: String`

**Note**: Does NOT restore deleted conversations or contacts

#### `reportUser(reporterID:reportedID:reason:)`

Reports user for inappropriate behavior.

**Parameters**:
- `reporterID: String` - User reporting
- `reportedID: String` - User being reported
- `reason: String` - Report reason

**Stored In**: `reports/` collection for admin review

#### `isBlocked(blockerID:blockedID:)`

Checks if user is blocked.

**Returns**: `Bool` - True if blocked

**Use Cases**:
- UI state (show "Unblock" vs "Block")
- Message send validation
- Contact list filtering

---

### MessageSyncService

#### `queueMessage(_:conversationID:currentUserID:modelContext:)`

Queues message for sending (online or offline).

**Parameters**:
- `message: Message` - Message to send
- `conversationID: String`
- `currentUserID: String`
- `modelContext: ModelContext`

**Flow**:
```swift
// 1. Save locally
message.status = networkMonitor.isConnected ? .sending : .pending
modelContext.insert(message)

// 2. If online, send immediately
if networkMonitor.isConnected {
    try await sendMessage(message, conversationID: conversationID)
} else {
    // Queued for later sync
    pendingMessageCount += 1
}
```

#### `syncPendingMessages()`

Syncs all queued messages.

**Automatically Triggered**:
- When network connection restored
- On app foreground
- Manual refresh

**Retry Logic**:
- 3 max attempts per message
- Exponential backoff: 2s, 4s, 8s
- Mark as failed after max retries

---

### TypingIndicatorService

#### `startTyping(conversationID:userID:)`

Indicates user started typing.

**Parameters**:
- `conversationID: String`
- `userID: String`

**Firestore Update**:
```javascript
typingUsers: FieldValue.arrayUnion([userID])
```

**Auto-Cleanup**: Removed after 3 seconds of inactivity

#### `stopTyping(conversationID:userID:)`

Removes typing indicator.

**Triggers**:
- Message sent
- Text field loses focus
- User navigates away
- After 3 second timeout

---

### AIService

#### `summarizeThread(conversationID:messageLimit:)`

Generates conversation summary.

**Parameters**:
- `conversationID: String`
- `messageLimit: Int` - Default: 100

**Returns**: `ConversationSummary`
```swift
struct ConversationSummary {
    let points: [String]       // Summary bullet points
    let messageCount: Int      // Messages analyzed
    let timestamp: Date        // When generated
}
```

**Processing Time**: 8-15 seconds

**Cost**: ~$0.05-0.10 per call

#### `extractActionItems(conversationID:)`

Extracts tasks from conversation.

**Returns**: `ActionItemsResult`
```swift
struct ActionItemsResult {
    let items: [ActionItem]
}

struct ActionItem {
    let id: String
    let task: String
    let assignee: String?
    let deadline: Date?
    let priority: String?
}
```

**Filters**:
- Includes explicit commitments
- Includes questions needing answers
- Includes problems to solve
- Excludes completed tasks
- Excludes pure acknowledgments

#### `trackDecisions(conversationID:)`

Identifies decisions made.

**Returns**: `DecisionsResult`
```swift
struct DecisionsResult {
    let decisions: [Decision]
}

struct Decision {
    let id: String
    let decision: String
    let topic: String
    let participants: [String]
    let timestamp: String?
    let confidence: ConfidenceLevel
}

enum ConfidenceLevel: String {
    case high, medium, low
}
```

#### `smartSearch(conversationID:query:)`

Semantic search across messages.

**Parameters**:
- `conversationID: String`
- `query: String` - Natural language query

**Returns**: `SmartSearchResults`
```swift
struct SmartSearchResults {
    let results: [SearchResult]
    let summary: String?
}

struct SearchResult {
    let id: String
    let message: String
    let sender: String?
    let timestamp: Date
    let relevanceScore: Double  // 0.0 - 1.0
    let category: String?
    let context: String?
}
```

**Result Ranking**: Sorted by `relevanceScore` descending

**Limit**: Top 10 results returned

#### `detectPriority(messageText:conversationContext:)`

Analyzes message priority.

**Parameters**:
- `messageText: String` - Message to analyze
- `conversationContext: String?` - Optional context

**Returns**: `PriorityResult`
```swift
struct PriorityResult {
    let isUrgent: Bool
    let urgencyScore: Double       // 0-100
    let reason: String?
    let priority: String           // "high", "medium", "low"
    let urgencyIndicators: [String]
}
```

**Score Thresholds**:
- HIGH: 70-100
- MEDIUM: 20-69
- LOW: 0-19

---

## Firebase Cloud Functions

### summarizeThread

**Type**: HTTPS Callable

**Request**:
```javascript
{
  conversationId: string,
  messageLimit?: number  // Default: 100
}
```

**Response**:
```javascript
{
  summary: string[],           // Array of bullet points
  messageCount: number,        // Messages analyzed
  generatedAt: string         // ISO timestamp
}
```

**Error Codes**:
- `unauthenticated`: User not signed in
- `invalid-argument`: Missing conversationId
- `internal`: Processing error

### extractActionItems

**Request**:
```javascript
{
  conversationId: string,
  messageLimit?: number  // Default: 100
}
```

**Response**:
```javascript
{
  items: [
    {
      task: string,
      assignee: string | null,
      deadline: string | null,  // ISO date or "ASAP"
      priority: "high" | "medium" | "low"
    }
  ],
  actionItems: [...],          // Duplicate for compatibility
  totalCount: number,
  generatedAt: string
}
```

### trackDecisions

**Request**:
```javascript
{
  conversationId: string,
  messageLimit?: number  // Default: 100
}
```

**Response**:
```javascript
{
  decisions: [
    {
      decision: string,
      topic: string,
      participantsInvolved: string[],
      confidence: "high" | "medium" | "low",
      timestamp?: string
    }
  ],
  totalCount: number,
  generatedAt: string
}
```

### smartSearch

**Request**:
```javascript
{
  conversationId: string,
  query: string,
  messageLimit?: number  // Default: 200
}
```

**Response**:
```javascript
{
  results: [
    {
      snippet: string,
      messageId: number,
      relevanceScore: number,  // 0.0 - 1.0
      category?: string,
      context?: string,
      sender?: string
    }
  ],
  summary?: string,
  totalResults: number,
  generatedAt: string
}
```

### detectPriority

**Request**:
```javascript
{
  messageText: string,
  conversationContext?: string
}
```

**Response**:
```javascript
{
  priority: "high" | "medium" | "low",
  urgencyScore: number,      // 0-100
  isUrgent: boolean,
  reason?: string,
  urgencyIndicators: string[],
  confidence?: string,
  recommendedAction?: string,
  timeframe?: string,
  category?: string
}
```

### checkBlockOnMessage (Firestore Trigger)

**Type**: Firestore onCreate Trigger

**Trigger**: `conversations/{conversationId}/messages/{messageId}`

**Behavior**:
1. Checks if sender is blocked by recipient
2. If blocked:
   - Deletes the message
   - Sends auto-reply: "This user has blocked you"
3. If not blocked: No action

**Implementation**:
```javascript
exports.checkBlockOnMessage = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const senderID = message.senderID;
    
    // Get recipient
    const conversation = await getConversation(context.params.conversationId);
    const recipientID = conversation.participantIDs.find(id => id !== senderID);
    
    // Check block status
    const recipient = await getUser(recipientID);
    if (recipient.blockedUsers?.includes(senderID)) {
      await snap.ref.delete();
      await sendSystemMessage(conversationId, "This user has blocked you");
    }
  });
```

### healthCheck

**Type**: HTTPS Callable

**Request**: `{}` (empty)

**Response**:
```javascript
{
  status: "healthy" | "unhealthy",
  message: string,
  openaiResponse?: string,
  timestamp: string
}
```

**Purpose**: Verify OpenAI connectivity and function deployment

---

## Models Reference

### User

**SwiftData Model**:
```swift
@Model
class User: Identifiable, Codable {
    @Attribute(.unique) var id: String
    var email: String
    var displayName: String
    var profilePictureURL: String?
    var status: String?
    var isOnline: Bool
    var lastSeen: Date?
    var lastHeartbeat: Date?
    var blockedUsers: [String]
    var showOnlineStatus: Bool
    
    var isActuallyOnline: Bool { ... }  // Computed property
}
```

**Codable Keys**:
```swift
enum CodingKeys: String, CodingKey {
    case id, email, displayName, profilePictureURL, status,
         isOnline, lastSeen, lastHeartbeat, blockedUsers, showOnlineStatus
}
```

**Firestore Conversion**:
```swift
func toDictionary() -> [String: Any]
static func fromDictionary(_ data: [String: Any]) -> User?
```

**Computed Properties**:
- `isActuallyOnline`: True if heartbeat within 20 seconds

### Conversation

```swift
@Model
class Conversation: Identifiable {
    @Attribute(.unique) var id: String
    var isGroup: Bool
    var name: String?
    var groupPictureURL: String?
    var participantIDs: [String]
    var lastMessage: String?
    var lastMessageTime: Date?
    var lastSenderID: String?
    var lastMessageID: String?
    var unreadBy: [String]
    var creatorID: String?
    var deletedBy: [String]
}
```

**Key Fields**:
- `isGroup`: Distinguishes 1-on-1 from group chats
- `participantIDs`: All users in conversation
- `unreadBy`: Users who haven't read latest message
- `deletedBy`: Users who deleted conversation (soft delete)
- `creatorID`: Only set for groups, determines admin rights

### Message

```swift
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
    var syncAttempts: Int
    var lastSyncAttempt: Date?
    var needsSync: Bool
    
    var status: MessageStatus { get set }
}
```

**MessageType Enum**:
```swift
enum MessageType: String, Codable {
    case text
    case image
    case voice
}
```

**MessageStatus Enum**:
```swift
enum MessageStatus: String, Codable {
    case pending    // Queued for sending
    case sending    // Upload in progress
    case sent       // Uploaded successfully
    case delivered  // Received by recipient
    case read       // Viewed by recipient
    case failed     // Failed after retries
}
```

---

## ViewModels

### AuthViewModel

**Purpose**: Manages global authentication state.

```swift
@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    var isAuthenticated: Bool { currentUser != nil }
    
    func checkAuthState() async
    func signUp(email: String, password: String, displayName: String) async
    func signIn(email: String, password: String) async
    func signOut()
}
```

**Lifecycle**:
```swift
init() {
    Task {
        await checkAuthState()  // Check on app launch
    }
}
```

**State Management**:
- `currentUser`: Global user state, injected via `@EnvironmentObject`
- Auto-starts presence updates on sign in
- Stops presence on sign out

---

## Utilities

### NetworkMonitor

**Purpose**: Monitor internet connectivity.

```swift
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    @Published var isConnected: Bool = true
    
    private let monitor = NWPathMonitor()
}
```

**Usage**:
```swift
@StateObject private var networkMonitor = NetworkMonitor.shared

if !networkMonitor.isConnected {
    Text("No Internet Connection")
}
```

### DiagnosticHelper

**Purpose**: Debug tools for development.

```swift
class DiagnosticHelper {
    static func runDiagnostics() {
        // Firebase configuration check
        // Model validation
        // Network status
        // Memory usage
    }
}
```

**Enabled**: Only in DEBUG builds

### NotificationManager

**Purpose**: In-app and system notifications.

```swift
class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    func setup() async
    func requestPermissions() async -> Bool
    func showNotification(title: String, body: String, conversationID: String)
    func enterChat(_ conversationID: String)
    func exitChat()
}
```

**In-App Notifications**:
- Only shown when NOT in active chat
- Tap to navigate to conversation
- Auto-dismiss after 3 seconds

---

## Advanced Patterns

### Firestore Query Optimization

**Index Requirements**:
```javascript
// conversations collection
{
  fields: ["participantIDs", "lastMessageTime"],
  order: "descending"
}
```

**Composite Queries**:
```swift
// Efficient: Uses index
db.collection("conversations")
    .whereField("participantIDs", arrayContains: userID)
    .order(by: "lastMessageTime", descending: true)
    .limit(to: 20)
```

**Inefficient Queries to Avoid**:
```swift
// ❌ No index - will fail or be slow
db.collection("conversations")
    .whereField("participantIDs", arrayContains: userID)
    .whereField("isGroup", isEqualTo: false)
    .order(by: "lastMessageTime", descending: true)
```

### Real-time Listener Best Practices

**1. Always Remove on Dismiss**:
```swift
var listener: ListenerRegistration?

.onDisappear {
    listener?.remove()
    listener = nil
}
```

**2. Handle Errors Gracefully**:
```swift
.addSnapshotListener { snapshot, error in
    if let error = error {
        print("Listener error: \(error)")
        return  // Don't crash, just log
    }
    
    guard let snapshot = snapshot else { return }
    // Process snapshot
}
```

**3. Batch UI Updates**:
```swift
// Bad: Update UI for each change
for change in changes {
    self.messages.append(parseMessage(change))  // Multiple UI refreshes
}

// Good: Collect changes, update once
var messagesToAdd: [Message] = []
for change in changes {
    messagesToAdd.append(parseMessage(change))
}

Task { @MainActor in
    self.messages.append(contentsOf: messagesToAdd)  // Single UI refresh
}
```

---

## Configuration

### Info.plist Settings

**Required Keys**:
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>MessageAI needs access to your photos to send images</string>

<key>NSMicrophoneUsageDescription</key>
<string>MessageAI needs microphone access to record voice messages</string>

<key>NSCameraUsageDescription</key>
<string>MessageAI needs camera access to take photos</string>
```

**Network Configuration**:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

### Firebase Configuration

**GoogleService-Info.plist** (never commit this!):
- Contains API keys and project configuration
- Auto-downloaded from Firebase Console
- Place in MessageAI/MessageAI/ directory
- Add to .gitignore

**Functions Configuration**:
```json
{
  "functions": {
    "source": "functions",
    "runtime": "nodejs20",
    "predeploy": ["npm --prefix \"$RESOURCE_DIR\" run lint"]
  }
}
```

---

## Migration Guides

### Adding New Message Type

1. **Update MessageType enum**:
```swift
enum MessageType: String, Codable {
    case text
    case image
    case voice
    case video  // New type
}
```

2. **Create bubble component**:
```swift
struct VideoMessageBubble: View { ... }
```

3. **Update ChatView**:
```swift
switch message.type {
case .text: TextMessageBubble(...)
case .image: ImageMessageBubble(...)
case .voice: VoiceMessageBubble(...)
case .video: VideoMessageBubble(...)  // Add new case
}
```

4. **Add upload logic**:
```swift
func uploadVideo(_ video: URL, conversationID: String) async throws -> String
```

### Adding New AI Feature

1. **Define agent in functions/index.js**:
```javascript
const NEW_AGENT = {
  name: "AgentName",
  model: "gpt-4-turbo-preview",
  instructions: `...`
};
```

2. **Create Cloud Function**:
```javascript
exports.newFeature = functions.https.onCall(async (data, context) => {
  // Implementation
});
```

3. **Add Swift model**:
```swift
struct NewFeatureResult: Codable {
    let data: [String]
}
```

4. **Add AIService method**:
```swift
func newFeature(conversationID: String) async throws -> NewFeatureResult
```

5. **Create UI view**:
```swift
struct NewFeatureView: View { ... }
```

6. **Add to AIFeaturesView tabs**

---

## Debugging Tools

### Console Logging

**AIService** (enabled when `debugMode = true`):
```
ℹ️ AIService: Starting health check...
📤 AIService: Calling summarizeThread
ℹ️ AIService: ConversationID: ABC123, MessageLimit: 100
📥 AIService: Received response from summarizeThread
ℹ️ AIService: Response data: {...}
✅ AIService: Successfully parsed summary with 15 points
```

**ChatView**:
```
👂 ChatView: Setting up message listener for conversation ABC123...
🧹 Cleared local messages array for fresh load
📨 ChatView: Received snapshot with 25 messages
   Document changes: 1
   Is initial load: true
   🔄 Initial load: Processing all 25 documents
   ✅ Parsed message: type=text, content='Hello', mediaURL=NO
   ➕ Will add message: 'Hello' from user123...
```

### Firebase Emulator

**Setup**:
```bash
firebase init emulators
# Select: Firestore, Storage, Functions

firebase emulators:start
```

**Update iOS app**:
```swift
#if DEBUG
let db = Firestore.firestore()
db.useEmulator(withHost: "localhost", port: 8080)

let storage = Storage.storage()
storage.useEmulator(withHost: "localhost", port: 9199)

let functions = Functions.functions()
functions.useEmulator(withHost: "localhost", port: 5001)
#endif
```

**Benefits**:
- Test without real Firebase
- Faster development iteration
- No costs during development
- Offline development

---

## Common Pitfalls

### 1. SwiftData Model Updates

**❌ Wrong**:
```swift
var updatedUser = currentUser  // Creates copy
updatedUser.name = "New Name"
authViewModel.currentUser = updatedUser  // Doesn't update original
```

**✅ Correct**:
```swift
currentUser.name = "New Name"  // Updates directly (it's a class)
// No need to reassign
```

### 2. Async in init

**❌ Wrong**:
```swift
init() {
    Task {
        await loadData()  // Will crash
    }
}
```

**✅ Correct**:
```swift
.task {
    await loadData()  // Proper lifecycle
}
```

### 3. Firestore Timestamp Conversion

**❌ Wrong**:
```swift
let date = data["timestamp"] as? Date  // Returns nil!
```

**✅ Correct**:
```swift
if let timestamp = data["timestamp"] as? Timestamp {
    let date = timestamp.dateValue()
}
```

### 4. Main Actor UI Updates

**❌ Wrong**:
```swift
Task {
    let data = await fetchData()
    self.data = data  // May not be on main thread
}
```

**✅ Correct**:
```swift
Task {
    let data = await fetchData()
    await MainActor.run {
        self.data = data
    }
}
```

---

## Performance Tips

### 1. Lazy Loading

```swift
// Instead of ForEach (loads all immediately)
LazyVStack {
    ForEach(messages) { message in
        MessageView(message: message)
    }
}
```

### 2. Debouncing

```swift
// Typing indicator with debounce
@State private var typingTask: Task<Void, Never>?

func textDidChange() {
    typingTask?.cancel()
    typingTask = Task {
        try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms
        await startTyping()
    }
}
```

### 3. Pagination (Not Implemented)

```swift
// Future implementation
func loadMoreMessages() async {
    let query = db.collection("conversations")
        .document(conversationID)
        .collection("messages")
        .order(by: "timestamp", descending: true)
        .start(afterDocument: lastDocument)  // Pagination cursor
        .limit(to: 50)
    
    let snapshot = try await query.getDocuments()
    lastDocument = snapshot.documents.last
}
```

---

## Security Checklist

- [ ] All API keys in environment variables
- [ ] No sensitive data in logs
- [ ] Firestore rules restrict access
- [ ] Storage rules enforce permissions
- [ ] User input validated
- [ ] Authentication required for all operations
- [ ] Block system prevents harassment
- [ ] Report system captures abuse
- [ ] Messages encrypted in transit (HTTPS)
- [ ] No XSS vulnerabilities

---

## Deployment Scripts

### Full Deployment

```bash
#!/bin/bash

# Deploy Firebase Functions
cd functions
firebase deploy --only functions
cd ..

# Update Firestore rules
firebase deploy --only firestore:rules

# Update Storage rules
firebase deploy --only storage:rules

# Archive iOS app
xcodebuild -scheme MessageAI -archivePath build/MessageAI.xcarchive archive

# Export for App Store
xcodebuild -exportArchive -archivePath build/MessageAI.xcarchive \
  -exportPath build/ -exportOptionsPlist ExportOptions.plist

echo "Deployment complete!"
```

### Function-Only Deployment

```bash
cd functions && firebase deploy --only functions && cd ..
```

### Specific Function

```bash
firebase deploy --only functions:summarizeThread
```

---

## Monitoring

### Firebase Console Metrics

**Check Daily**:
- Function invocations and errors
- Firestore read/write operations
- Storage bandwidth
- Authentication activity

**Set Alerts For**:
- Function error rate > 5%
- Firestore costs spike
- Unusual authentication patterns
- Storage quota approaching limit

### Xcode Metrics

**Memory Graph Debugger**:
1. Run app
2. Debug → View Memory Graph
3. Look for retain cycles
4. Fix strong references

**Time Profiler**:
1. Profile → Time Profiler
2. Record session
3. Find hotspots (>10% CPU)
4. Optimize slow functions

---

## Future Enhancements

### Planned Technical Improvements

1. **Pagination**: Load messages in chunks
2. **WebSocket**: Direct Firebase connection (not snapshots)
3. **Push Notifications**: APNs integration
4. **End-to-End Encryption**: Signal protocol
5. **Message Search**: Full-text search in Firestore
6. **Media Thumbnails**: Generate previews
7. **Compression**: Better image/video compression
8. **Caching**: Redis for AI results
9. **Analytics**: Privacy-friendly usage tracking
10. **A/B Testing**: Feature experimentation

---

*This documentation is maintained alongside the codebase. Last updated: October 26, 2025.*

