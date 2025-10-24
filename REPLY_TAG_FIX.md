# Reply Tag Display Fix

## Problem
When replying to messages, the reply bubble was showing the user ID (e.g., "yjmE7XXCXyVPbYbXMMEF3glc1o73") instead of the user's display name.

## Root Cause
The `MessageBubble` component was receiving `replyToSenderID` (the user's Firebase UID) and passing it directly to `ReplyBubbleView` as the display name.

## Solution

### 1. Added User Display Name Cache
Added a state variable in `ChatView` to cache fetched user display names:
```swift
@State private var userDisplayNames: [String: String] = [:]
```

### 2. Created Helper Functions
Added two helper functions in `ChatView`:

**`getSenderDisplayName(for:)`**
- Returns "You" if the user ID matches the current user
- Returns the cached display name if available
- Returns "Loading..." as a fallback

**`loadUserDisplayName(for:)`**
- Fetches user data from Firestore
- Caches the display name in `userDisplayNames`
- Skips if already cached or is current user

### 3. Updated MessageBubble Component
- Added `replySenderName: String?` parameter to `MessageBubble` struct
- The display name is now resolved in `ChatView` and passed to `MessageBubble`
- Removed the need for `MessageBubble` to access `ChatView`'s functions

### 4. Updated MessageBubble Instantiation
In `ChatView.messageView(for:)`:
- Passes `replySenderName` by calling `getSenderDisplayName()` if a reply exists
- Added `.onAppear` to load the user's display name asynchronously
- The UI updates automatically when the name is fetched

## How It Works Now

1. **Initial Render**: Shows "Loading..." if the name isn't cached yet
2. **Background Fetch**: Asynchronously fetches the user's display name from Firestore
3. **Cache Update**: Stores the name in `userDisplayNames` dictionary
4. **UI Update**: SwiftUI automatically re-renders with the actual name
5. **Subsequent Renders**: Uses the cached name immediately (no "Loading..." flash)

## Result

Reply bubbles now display:
- ✅ **"You"** when replying to your own message
- ✅ **User's actual display name** (e.g., "Cdcd") when replying to others
- ✅ **"Loading..."** briefly during first fetch (then updates to actual name)

## Files Modified
- `MessageAI/Views/ChatView.swift`
  - Added `userDisplayNames` state variable
  - Added `getSenderDisplayName()` and `loadUserDisplayName()` helper functions
  - Updated `MessageBubble` struct to accept `replySenderName` parameter
  - Updated `MessageBubble` instantiation to pass the display name

## Testing
Test in both:
- ✅ **1-on-1 chats**: Reply to messages from the other user
- ✅ **Group chats**: Reply to messages from different group members
- ✅ **Self-replies**: Reply to your own messages (should show "You")

## Edge Cases Handled
- Current user replies to themselves → Shows "You"
- First time seeing a user → Shows "Loading..." then updates
- Cached users → Shows name immediately
- Firestore fetch fails → Shows "Loading..." (doesn't crash)

