# Crash and Conversation List Fixes

**Date:** October 24, 2025  
**Issues Fixed:**
1. Random crash when deleting the last message in a chat
2. New messages not appearing in conversation list after sending

---

## Issue 1: Crash When Deleting Last Message

### Problem
The app would crash (especially on physical devices) when deleting the last message in a chat. This was caused by SwiftUI's `ScrollViewReader` trying to scroll to a message that no longer exists.

### Root Cause
```swift
.onChange(of: messages.count) { _, _ in
    if let lastMessage = messages.last {
        withAnimation {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)  // ❌ Crashes if message was just deleted
        }
    }
}
```

When a message is deleted:
1. SwiftUI removes the view from the hierarchy
2. The `messages.count` changes, triggering `onChange`
3. `scrollTo` tries to scroll to a message that's already been removed
4. **CRASH** 💥

### Solution
**File: `MessageAI/Views/ChatView.swift` (lines 53-75)**

Added safety checks and delays to ensure SwiftUI has finished rendering before scrolling:

```swift
.onChange(of: messages.count) { oldCount, newCount in
    // Only scroll if we have messages and the count changed
    guard !messages.isEmpty, oldCount != newCount else { return }
    
    // Small delay to ensure SwiftUI has rendered the new message
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        if let lastMessage = messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

.onChange(of: isOtherUserTyping) { _, isTyping in
    if isTyping {
        // Small delay to ensure typing indicator is rendered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation {
                proxy.scrollTo("typing-indicator", anchor: .bottom)
            }
        }
    }
}
```

**Key Improvements:**
- ✅ Check `!messages.isEmpty` before scrolling
- ✅ Check `oldCount != newCount` to avoid redundant scrolls
- ✅ Add 0.1s delay to ensure SwiftUI has finished rendering
- ✅ Same protection for typing indicator

---

## Issue 2: New Messages Not Appearing in Conversation List

### Problem
After sending a message in a new chat, the conversation would not appear or update in the conversation list. The message was being sent to Firestore, but the conversation document wasn't being updated properly.

### Root Cause
The conversation document update was using `merge: true`, but only updating a few fields:

```swift
try await db.collection("conversations")
    .document(conversation.id)
    .setData([
        "lastMessage": content,
        "lastMessageTime": Timestamp(date: Date()),
        "lastSenderID": currentUser.id,
        "lastMessageID": message.id,
        "unreadBy": otherParticipants
    ], merge: true)
```

**Problem:** For **new conversations**, this creates an incomplete document that's missing required fields like:
- `id`
- `participantIDs` (required for the listener query!)
- `isGroup`
- `name`
- `creatorID`

The `ConversationListView` listener queries:
```swift
.whereField("participantIDs", arrayContains: currentUser.id)
```

If `participantIDs` is missing, the conversation won't show up in the query results! 🚨

### Solution
**Files Updated:**
- `MessageAI/Views/ChatView.swift` - `sendMessage()` (lines 868-884)
- `MessageAI/Views/ChatView.swift` - `sendImageMessage()` (lines 963-979)
- `MessageAI/Views/ChatView.swift` - `sendVoiceMessage()` (lines 1067-1083)

**Updated all three functions to include ALL conversation fields:**

```swift
try await db.collection("conversations")
    .document(conversation.id)
    .setData([
        "id": conversation.id,                          // ✅ Added
        "participantIDs": conversation.participantIDs,  // ✅ CRITICAL - required for query
        "isGroup": conversation.isGroup,                // ✅ Added
        "name": conversation.name ?? "",                // ✅ Added
        "lastMessage": content,
        "lastMessageTime": Timestamp(date: Date()),
        "lastSenderID": currentUser.id,
        "lastMessageID": message.id,
        "unreadBy": otherParticipants,
        "creatorID": conversation.creatorID ?? currentUser.id  // ✅ Added
    ], merge: true)
```

**Why This Works:**
1. ✅ **New conversations** get a complete document with all required fields
2. ✅ **Existing conversations** get updated (merge: true preserves other fields)
3. ✅ The `participantIDs` field is always present, so the listener query works
4. ✅ All three message types (text, image, voice) now use the same robust update

---

## Testing Checklist

### Deletion Crash Fix
- [x] Delete last message in chat → No crash
- [x] Delete multiple messages rapidly → No crash
- [x] Delete message while typing indicator showing → No crash
- [x] Test on physical device → No crash
- [x] Test on simulator → No crash

### Conversation List Update Fix
- [x] Create new chat → Send message → Appears in list immediately
- [x] Send text message → List updates with preview
- [x] Send image message → List updates with "📷 Photo"
- [x] Send voice message → List updates with "🎤 Voice message"
- [x] Conversation moves to top of list after new message
- [x] Unread indicator (blue dot) appears for recipient
- [x] Test on physical device → Works
- [x] Test on simulator → Works

---

## Technical Details

### Why the 0.1s Delay?
SwiftUI's rendering is asynchronous. When you delete a message:
1. State changes (`messages` array updated)
2. SwiftUI schedules a re-render
3. `onChange` fires **immediately** (before re-render completes)
4. `scrollTo` tries to find a view that's being removed
5. **Crash**

The 0.1s delay ensures:
- SwiftUI has finished removing the deleted message view
- The new last message (if any) is fully rendered
- `scrollTo` can safely find and scroll to the target

### Why Include All Conversation Fields?
Firestore's `setData(merge: true)` is smart:
- If document exists → Updates only the provided fields
- If document doesn't exist → Creates a new document with only those fields

For **new conversations**, we need the document to be complete from the start, especially `participantIDs` which is required for the query:

```swift
.whereField("participantIDs", arrayContains: currentUser.id)
```

Without `participantIDs`, the conversation is invisible to the listener!

---

## Related Files

### Modified
- `MessageAI/Views/ChatView.swift`
  - Lines 53-75: Scroll crash fix
  - Lines 868-884: Text message conversation update
  - Lines 963-979: Image message conversation update
  - Lines 1067-1083: Voice message conversation update

### Unchanged (but relevant)
- `MessageAI/Views/ConversationListView.swift` - Listener query
- `MessageAI/Models/Conversation.swift` - Model definition
- `MessageAI/Services/DeleteMessageService.swift` - Deletion logic

---

## Status
✅ **FIXED** - Both issues resolved
- No more crashes when deleting messages
- Conversation list updates immediately for all message types
- Tested on both physical device and simulator

---

## Next Steps
1. Monitor for any edge cases in production
2. Consider adding analytics to track deletion patterns
3. Consider adding undo functionality for deletions

