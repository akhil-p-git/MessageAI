# Presence System & AI Action Items Fixes

## Issue 1: Presence System Not Working

### Problem
Users still showed as "Online" even when they lost internet connection. Only the privacy setting ("Appear offline") would make them go offline.

### Root Cause
The presence system was using Firestore's `isOnline` boolean, but Firestore has offline persistence. When a user loses connection, their cached `isOnline: true` status remains visible to others.

### Solution: Heartbeat-Based Presence

Implemented a heartbeat system with client-side validation:

1. **Added `lastHeartbeat` field** to User model
   - Tracks the last time the user sent a heartbeat (every 15 seconds)
   - Uses `FieldValue.serverTimestamp()` for accurate server-side timing

2. **Created `isActuallyOnline` computed property**
   ```swift
   var isActuallyOnline: Bool {
       guard showOnlineStatus, isOnline, let heartbeat = lastHeartbeat else {
           return false
       }
       let timeSinceHeartbeat = Date().timeIntervalSince(heartbeat)
       return timeSinceHeartbeat < 30 // Consider online if heartbeat within 30 seconds
   }
   ```

3. **Reduced heartbeat interval** from 30s to 15s
   - More responsive to connection loss
   - User appears offline within 30 seconds of losing connection

4. **Updated UI components** to use `isActuallyOnline`
   - `ChatView`: Uses `user.isActuallyOnline` for status indicator
   - `ConversationListView`: Uses `user.isActuallyOnline` for green dot
   - `LastSeenView`: Uses `user.isActuallyOnline` for "Online" text

### How It Works Now

**When user loses internet:**
1. Heartbeat stops (no more updates every 15s)
2. `lastHeartbeat` becomes stale (> 30 seconds old)
3. `isActuallyOnline` returns `false`
4. Other users see them as offline

**When user regains internet:**
1. Heartbeat resumes immediately
2. `lastHeartbeat` updated to current time
3. `isActuallyOnline` returns `true`
4. Other users see them as online

**Privacy setting still works:**
- If `showOnlineStatus = false`, user always appears offline
- If `showOnlineStatus = true`, actual online status is shown

---

## Issue 2: AI Action Items Parsing Error

### Problem
Action Items extraction was failing with parsing error:
```
❌ AIService: Failed to parse action items from response
❌ AIService: Parsing error - Domain: MessageAI.AIServiceError, Code: 3
```

### Root Cause
The backend returns `actionItems` key, but the Swift parser was only looking for `items` key.

**Backend response:**
```json
{
  "actionItems": [...],
  "generatedAt": "2025-10-24T..."
}
```

**Swift parser expected:**
```json
{
  "items": [...]
}
```

### Solution: Flexible Parsing

Updated `ActionItemsResult` initializer to accept both keys:

```swift
init?(from dict: [String: Any]) {
    // Try multiple possible keys for flexibility
    let itemsArray: [[String: Any]]
    
    if let items = dict["items"] as? [[String: Any]] {
        itemsArray = items
    } else if let actionItems = dict["actionItems"] as? [[String: Any]] {
        itemsArray = actionItems
    } else {
        print("❌ ActionItemsResult: Could not find 'items' or 'actionItems' key")
        print("   Available keys: \(dict.keys)")
        return nil
    }
    
    self.items = itemsArray.compactMap { ActionItem(from: $0) }
}
```

### Enhanced Logging

Added detailed logging to `AIService.extractActionItems()`:
```swift
self.log("Response data keys: \(data.keys.joined(separator: ", "))", type: .info)
self.log("Full response: \(data)", type: .info)
```

This helps debug future parsing issues by showing exactly what the backend returned.

---

## Files Modified

### Presence System:
1. **`MessageAI/Models/User.swift`**
   - Added `lastHeartbeat: Date?` property
   - Added `isActuallyOnline` computed property
   - Updated `toDictionary()`, `fromDictionary()`, and Codable methods

2. **`MessageAI/Services/PrescenceService.swift`**
   - Added `lastHeartbeat` to presence updates using `FieldValue.serverTimestamp()`
   - Reduced heartbeat interval from 30s to 15s
   - Added immediate first update on start

3. **`MessageAI/Views/ChatView.swift`**
   - Changed `user.isOnline` to `user.isActuallyOnline`

4. **`MessageAI/Views/ConversationListView.swift`**
   - Changed `user.showOnlineStatus && user.isOnline` to `user.isActuallyOnline`

### AI Action Items:
1. **`MessageAI/Models/AIModels.swift`**
   - Updated `ActionItemsResult.init(from:)` to accept both `items` and `actionItems` keys
   - Added debug logging for missing keys

2. **`MessageAI/Services/AI/AIService.swift`**
   - Enhanced logging in `extractActionItems()`
   - Added response structure logging
   - Added type checking before parsing

---

## Testing

### Presence System:
1. **Enable Airplane Mode**
   - Wait 30 seconds
   - Other users should see you as offline ✅

2. **Disable Airplane Mode**
   - Within 15 seconds, other users should see you as online ✅

3. **Close app**
   - Wait 30 seconds
   - Other users should see you as offline ✅

4. **Privacy setting**
   - Disable "Show online status"
   - You appear offline regardless of actual connection ✅

### AI Action Items:
1. **Send message with action item**
   - "We need to meet at a checkpoint in 2 hours"
   - Open AI panel → Action Items tab
   - Should extract the action item ✅

2. **Check console logs**
   - Should see response keys logged
   - Should see successful parsing
   - Should see action items count ✅

---

## Expected Console Output

### Presence (working):
```
👀 Started presence updates for abc123... (showOnline: true, interval: 15s)
✅ Updated presence: online (privacy: true)
✅ Updated presence: online (privacy: true)
...
📡 Network lost - stopping presence updates
```

### Action Items (working):
```
📤 AIService: 📤 Calling extractActionItems
ℹ️ AIService: ConversationID: 7E987ACA-FDBE-4476-BA67-D6981E087FA2
📥 AIService: 📥 Received response from extractActionItems
ℹ️ AIService: Response data keys: actionItems, generatedAt
ℹ️ AIService: Full response: ["actionItems": [...], "generatedAt": "2025-10-24T..."]
✅ AIService: ✅ Successfully parsed 1 action items
```

---

## Summary

✅ **Presence System**: Now uses heartbeat-based detection with 15-second intervals. Users appear offline within 30 seconds of losing connection.

✅ **AI Action Items**: Parser now accepts both `items` and `actionItems` keys, with enhanced logging for debugging.

Both issues are now resolved! 🎉

