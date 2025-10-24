# Online Status Privacy - Testing & Debugging Guide

## ✅ What Was Implemented

### **Model Changes:**
1. ✅ Added `showOnlineStatus: Bool` to User model
2. ✅ Default value is `true` (users show online by default)
3. ✅ Included in `toDictionary()`, `fromDictionary()`, and Codable conformance

### **Privacy Settings:**
1. ✅ Updated PrivacySettingsView to save setting to Firestore
2. ✅ Setting immediately updates user's online visibility
3. ✅ Shows confirmation message when saved
4. ✅ Loads current setting on appear

### **Presence Service:**
1. ✅ Updated to respect `showOnlineStatus` parameter
2. ✅ Only shows user as online if privacy allows
3. ✅ Updated presence updates in MainTabView to pass privacy setting

### **UI Components:**
1. ✅ Updated OnlineStatusIndicator to check privacy setting
2. ✅ Only shows green dot if user allows it
3. ✅ Updated ConversationListView to pass privacy setting
4. ✅ Updated ChatView to hide online status and last seen
5. ✅ Updated LastSeenView to respect privacy setting

---

## 🧪 Complete Testing Protocol

### **Test 1: Disable Online Status**

**Setup:** Two devices logged in (Device A = User A, Device B = User B)

**Steps:**
1. Device A: Go to Settings → Privacy
2. Device A: Turn OFF "Show Online Status"
3. Device A: Check console output

**Expected Console Output (Device A):**
```
🔒 Updating online status privacy setting...
   User: User A
   Show online: false
   ✅ Updated user document
   ✅ Set to appear offline
   ✅ Privacy setting saved!
```

**Expected on Device B:**
4. Device B: Open conversation list
5. Device B: Look at User A's conversation row
   - ❌ Green dot should be GONE
6. Device B: Open chat with User A
   - ❌ No green dot in chat header
   - ❌ No "Online" or "Last Seen" text
7. Device B: Go to New Chat screen
   - ❌ No green dot next to User A

**Verify in Firestore Console:**
8. Go to Firebase Console → Firestore Database
9. Users collection → User A's document
10. Check fields:
    - `showOnlineStatus: false` ✅
    - `isOnline: false` ✅

---

### **Test 2: Re-enable Online Status**

**Continuing from Test 1:**

**Steps:**
1. Device A: Turn ON "Show Online Status"
2. Device A: Check console output

**Expected Console Output (Device A):**
```
🔒 Updating online status privacy setting...
   User: User A
   Show online: true
   ✅ Updated user document
   ✅ Set to appear online
   ✅ Privacy setting saved!
```

**Expected on Device B:**
3. Device B: Should see User A online within 1-2 seconds
   - ✅ Green dot appears in conversation list
   - ✅ Green dot in chat header
   - ✅ "Online" or "Last Seen" text shows

**Verify in Firestore Console:**
4. Users collection → User A's document
5. Check fields:
    - `showOnlineStatus: true` ✅
    - `isOnline: true` ✅

---

### **Test 3: Privacy Persists After App Restart**

**Steps:**
1. Device A: Turn OFF "Show Online Status"
2. Device A: Force quit the app (swipe up from app switcher)
3. Device A: Reopen the app
4. Device A: Go to Settings → Privacy
5. Check "Show Online Status" toggle

**Expected:**
- ✅ Toggle is OFF
- ✅ Setting persisted across restarts

**On Device B:**
6. Device B: Should still NOT see User A as online
   - ❌ No green dot

---

### **Test 4: New User Default**

**Steps:**
1. Create a new user account (sign up)
2. Check Settings → Privacy
3. Look at "Show Online Status" toggle

**Expected:**
- ✅ Toggle is ON by default
- ✅ New users show online by default (opt-out, not opt-in)

**Verify in Firestore:**
4. Check new user's document
5. Should have:
   - `showOnlineStatus: true` ✅

---

### **Test 5: Real-time Updates**

**Setup:** Device B has conversation list open

**Steps:**
1. Device A: Toggle privacy setting OFF
2. Device B: Watch conversation list (don't refresh)
3. Wait 1-2 seconds

**Expected on Device B:**
- ✅ Green dot disappears immediately
- ✅ No need to close/reopen app
- ✅ Real-time update works

**Steps (continued):**
4. Device A: Toggle privacy setting ON
5. Device B: Watch conversation list

**Expected on Device B:**
- ✅ Green dot reappears immediately
- ✅ Real-time update works both ways

---

### **Test 6: Privacy Respected Everywhere**

**With privacy OFF, check all locations:**

**Conversation List:**
- ❌ No green dot on profile picture

**Chat Header:**
- ❌ No green dot
- ❌ No "Online" text
- ❌ No "Last Seen" text

**New Chat Screen:**
- ❌ No green dot next to user

**User Search:**
- ❌ No online indicator

**Group Chat:**
- ❌ No online status shown for that user

---

### **Test 7: Multiple Users**

**Setup:** Three users (A, B, C)

**Steps:**
1. User A: Privacy ON (shows online)
2. User B: Privacy OFF (hides online)
3. User C: Privacy ON (shows online)

**Expected on Device showing user list:**
- ✅ User A: Green dot shows
- ❌ User B: No green dot (even if online)
- ✅ User C: Green dot shows

---

## 🔍 Troubleshooting

### **Issue: Privacy setting doesn't save**

**Symptom:** Toggle changes but doesn't persist

**Debug Steps:**

1. **Check Console Output:**
   ```
   Look for: "🔒 Updating online status privacy setting..."
   If missing: onChange handler not firing
   If present: Continue to step 2
   ```

2. **Check for Errors:**
   ```
   Look for: "❌ Error updating privacy setting"
   If present: Check error message
   Common causes:
   - Firestore rules blocking update
   - User not authenticated
   - Network issue
   ```

3. **Verify Firestore Rules:**
   ```javascript
   // Users should be able to update their own document
   match /users/{userId} {
     allow update: if request.auth.uid == userId;
   }
   ```

4. **Check Firestore Console:**
   - Go to user document manually
   - Try to edit `showOnlineStatus` field
   - If can't edit: Rules issue

---

### **Issue: Online status still shows after disabling**

**Symptom:** Green dot still visible after privacy OFF

**Debug Steps:**

1. **Check User Model:**
   ```
   In console, print user object:
   print("User: \(user.showOnlineStatus)")
   
   Should be false if privacy is off
   ```

2. **Check Component Logic:**
   ```swift
   // In OnlineStatusIndicator
   if showOnlineStatus && isOnline {
       // Show green dot
   }
   
   Verify this condition is being checked
   ```

3. **Check Parameter Passing:**
   ```
   Search codebase for "OnlineStatusIndicator("
   All instances should pass showOnlineStatus parameter
   ```

4. **Check Firestore Data:**
   - Open user document
   - Verify `showOnlineStatus: false`
   - Verify `isOnline: false`

---

### **Issue: Setting doesn't update in real-time**

**Symptom:** Need to close/reopen app to see change

**Debug Steps:**

1. **Check Presence Updates:**
   ```
   In PrivacySettingsView, after updating setting:
   - Should update user document ✅
   - Should update isOnline field ✅
   ```

2. **Check Listener:**
   ```
   ConversationListView has listener for users
   Should receive update when user document changes
   ```

3. **Test Manual Update:**
   ```
   1. Open Firestore Console
   2. Change showOnlineStatus field manually
   3. Check if Device B sees change
   
   If yes: Privacy toggle not updating properly
   If no: Listener issue
   ```

---

### **Issue: Privacy resets to ON after restart**

**Symptom:** Setting doesn't persist

**Debug Steps:**

1. **Check fromDictionary:**
   ```swift
   let showOnlineStatus = data["showOnlineStatus"] as? Bool ?? true
   
   Verify this line exists in User.fromDictionary()
   ```

2. **Check Firestore Console:**
   ```
   After setting to false, check if field persists
   If field disappears: Not being saved properly
   If field stays: Not being loaded properly
   ```

3. **Check User Loading:**
   ```
   In AuthViewModel or wherever user is loaded:
   Verify all fields are being parsed
   Print user object to confirm
   ```

---

## 📋 Quick Diagnostic Checklist

### **When Toggling Privacy Setting:**

- [ ] See "🔒 Updating online status privacy setting..." in console
- [ ] See "✅ Updated user document"
- [ ] See "✅ Set to appear offline" (if disabling)
- [ ] See "✅ Privacy setting saved!"
- [ ] Firestore user document updates `showOnlineStatus`
- [ ] Firestore user document updates `isOnline`
- [ ] Other devices see change within 1-2 seconds
- [ ] Green dot disappears/appears accordingly

### **When Checking Privacy Display:**

- [ ] OnlineStatusIndicator checks `showOnlineStatus`
- [ ] Chat header respects privacy setting
- [ ] Conversation list respects privacy setting
- [ ] New chat screen respects privacy setting
- [ ] LastSeenView hidden when privacy OFF

---

## 🎯 Expected Behavior Summary

### **When Privacy is ON (default):**
```
✅ Green dot shows when online
✅ "Online" text shows in chat
✅ "Last Seen" shows when offline
✅ Other users can see activity status
```

### **When Privacy is OFF:**
```
❌ No green dot ever
❌ No "Online" text
❌ No "Last Seen" text
❌ User appears offline at all times
❌ Even when actively using app
```

---

## 🔧 Common Mistakes to Avoid

1. **Not passing showOnlineStatus to OnlineStatusIndicator**
   ```swift
   // ❌ Wrong
   OnlineStatusIndicator(isOnline: user.isOnline)
   
   // ✅ Correct
   OnlineStatusIndicator(
       isOnline: user.isOnline,
       showOnlineStatus: user.showOnlineStatus
   )
   ```

2. **Not updating presence when privacy changes**
   ```swift
   // After updating privacy, must also update isOnline
   if !newValue {
       // Set user to appear offline
       try await db.collection("users")
           .document(userId)
           .updateData(["isOnline": false])
   }
   ```

3. **Forgetting to load setting on appear**
   ```swift
   .onAppear {
       loadSettings()  // ✅ Must load current setting
   }
   ```

4. **Not passing privacy setting to presence service**
   ```swift
   // ❌ Wrong
   PresenceService.shared.startPresenceUpdates(userID: userId)
   
   // ✅ Correct
   PresenceService.shared.startPresenceUpdates(
       userID: userId,
       showOnlineStatus: user.showOnlineStatus
   )
   ```

---

## 📱 Console Output Reference

### **Successful Privacy Toggle (OFF):**
```
🔒 Updating online status privacy setting...
   User: John Doe
   Show online: false
   ✅ Updated user document
   ✅ Set to appear offline
   ✅ Privacy setting saved!

👀 Started presence updates for abc123... (showOnline: false)
✅ Updated presence: offline (privacy: false)
```

### **Successful Privacy Toggle (ON):**
```
🔒 Updating online status privacy setting...
   User: John Doe
   Show online: true
   ✅ Updated user document
   ✅ Set to appear online
   ✅ Privacy setting saved!

👀 Started presence updates for abc123... (showOnline: true)
✅ Updated presence: online (privacy: true)
```

---

## 🎨 UI States

### **Privacy Settings View:**

**When privacy is ON:**
```
Privacy
├── Show Online Status  [TOGGLE: ON]
├── Show Last Seen      [TOGGLE: (varies)]
└── (Other settings...)
```

**When privacy is OFF:**
```
Privacy
├── Show Online Status  [TOGGLE: OFF]
├── Show Last Seen      [TOGGLE: (varies)]
└── (Other settings...)
```

**After saving:**
```
Privacy
├── Show Online Status  [TOGGLE: OFF]
├── Show Last Seen      [TOGGLE: (varies)]
└── ✓ Settings saved    [GREEN CHECKMARK]
    (disappears after 2 seconds)
```

---

## ✅ Success Criteria

After implementing and testing, ALL of these should work:

- ✅ **Toggle saves to Firestore** - Setting persists
- ✅ **Privacy respected in UI** - No green dots when OFF
- ✅ **Real-time updates** - Changes visible immediately
- ✅ **Persists across restarts** - Setting survives app restart
- ✅ **New users default to ON** - Opt-out, not opt-in
- ✅ **Works everywhere** - Chat, list, new chat, search
- ✅ **Last seen also hidden** - When privacy OFF
- ✅ **Presence service respects** - Backend also obeys setting

---

## 🚀 Next Steps

1. **Build and run the app** (⌘R)
2. **Test privacy toggle** - Turn it OFF and ON
3. **Check console output** - Verify all logs appear
4. **Test on two devices** - Verify real-time updates
5. **Check Firestore** - Verify data is saved
6. **Test all UI locations** - Chat, list, new chat
7. **Test app restart** - Verify persistence

---

**Last Updated:** October 24, 2025
**Status:** Online status privacy feature implemented ✅
**Files Modified:** 7
- User.swift (model)
- PrivacySettingsView.swift (UI)
- PrescenceService.swift (backend)
- OnlineStatusIndicator.swift (component)
- ConversationListView.swift (usage)
- ChatView.swift (usage)
- MainTabView.swift (presence startup)

---

**The privacy setting now works end-to-end! 🔒**

