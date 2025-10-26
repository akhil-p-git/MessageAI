# MessageAI Quick Start Guide

Get up and running with MessageAI in 10 minutes.

---

## For Users

### 1. Download & Install

1. Download MessageAI from the App Store (or via TestFlight)
2. Open the app on your iPhone
3. Allow notifications when prompted (optional but recommended)

### 2. Create Account

1. Tap **"Sign Up"**
2. Enter:
   - Email address
   - Password (min 6 characters)
   - Display name
3. Tap **"Create Account"**
4. You're in! 🎉

### 3. Start Your First Chat

**Option A: Message Someone**
1. Tap the **compose icon** (✏️) top right
2. Enter their email: `friend@example.com`
3. Tap the **red arrow** →
4. Type "Hey!" and hit send
5. Done! They'll receive your message instantly

**Option B: Create a Group**
1. Tap **"New Group"**
2. Name it: "Weekend Plans"
3. Select 2+ friends
4. Tap **"Create"**
5. Send your first group message!

### 4. Try an AI Feature

1. Send a few messages back and forth (at least 5)
2. Tap the **sparkles icon** ✨ in chat
3. Try **"Summary"** tab
4. Wait 10 seconds
5. See AI-generated summary! 🤖

**That's it!** You're now using AI-powered messaging.

---

## For Developers

### 1. Prerequisites

```bash
# Install tools
brew install node
npm install -g firebase-tools

# Verify installations
node --version  # Should be 18+
firebase --version
```

### 2. Clone & Configure

```bash
# Clone repository
git clone https://github.com/akhil-p-git/MessageAI.git
cd MessageAI

# Set up Firebase
firebase login
firebase init

# Select:
# - Firestore
# - Functions
# - Storage
```

### 3. Add Firebase Config

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create new project
3. Add iOS app
4. Download `GoogleService-Info.plist`
5. Place in `MessageAI/MessageAI/` folder

### 4. Configure Functions

```bash
cd functions
npm install

# Create .env file
echo "OPENAI_API_KEY=sk-your-key-here" > .env

# Deploy
firebase deploy --only functions
```

### 5. Open in Xcode

```bash
open MessageAI.xcodeproj
```

### 6. First Run

1. Select iPhone simulator (iOS 17+)
2. Press `Cmd+R` to build and run
3. Create a test account
4. Start messaging!

### 7. Test AI Features

```bash
# Check function deployment
firebase functions:log | grep summarizeThread

# Test function directly
firebase functions:shell
> summarizeThread({conversationId: "test", messageLimit: 10})
```

**Common Issues**:
- ❌ "No GoogleService-Info.plist" → Add Firebase config
- ❌ "OpenAI API error" → Check .env file has correct key
- ❌ "Permission denied" → Update Firestore rules
- ❌ "Build failed" → Clean build folder (Cmd+Shift+K)

---

## 5-Minute Feature Tour

### Minute 1: Basic Messaging
- Send text message ✉️
- Send photo 📷
- Send voice message 🎤

### Minute 2: Rich Features
- Reply to a message 💬
- React with emoji 😊
- Forward a message ➡️

### Minute 3: Groups
- Create a group 👥
- Add a group picture 📸
- Send a group message

### Minute 4: AI Magic
- Generate summary ✨
- Extract action items ✅
- Track decisions 🎯

### Minute 5: Contacts & Settings
- Add a contact 📇
- View their profile 👤
- Customize your settings ⚙️

**You're now a MessageAI expert!**

---

## Essential Shortcuts

| Action | Shortcut |
|--------|----------|
| Send message | Tap ↑ or press Return |
| New chat | Compose icon ✏️ |
| New group | "New Group" button |
| AI features | Sparkles icon ✨ |
| Search chat | ⋯ menu → Search Chat |
| Add contact | Contacts tab → + |
| Edit profile | Settings → tap profile |
| Toggle theme | Settings → Appearance |

---

## Next Steps

### For Users

1. **Invite Friends**: MessageAI is better with more users
2. **Explore AI**: Try all 5 AI features
3. **Customize**: Set your profile picture and status
4. **Organize**: Build your contact list
5. **Provide Feedback**: Help us improve!

### For Developers

1. **Read**: [TECHNICAL_DOCUMENTATION.md](TECHNICAL_DOCUMENTATION.md)
2. **Explore**: [API_REFERENCE.md](API_REFERENCE.md)
3. **Study**: [ARCHITECTURE.md](ARCHITECTURE.md)
4. **Customize**: Add your own AI agents
5. **Contribute**: Submit pull requests!

---

## Getting Help

**Quick Questions**:
- Check [USER_GUIDE.md](USER_GUIDE.md)
- Check [FAQ section](#faq)

**Technical Issues**:
- Check [TECHNICAL_DOCUMENTATION.md](TECHNICAL_DOCUMENTATION.md)
- Search GitHub Issues
- Create new issue with logs

**Feature Requests**:
- Open GitHub issue with [Feature Request] tag
- Describe use case and value
- Vote on existing requests

---

## Welcome to MessageAI! 🚀

You're now ready to experience the future of intelligent messaging.

**What makes MessageAI special?**
- 🤖 AI that actually helps (not just a gimmick)
- ⚡ Real-time everything
- 🎨 Beautiful, native iOS design
- 🔒 Privacy-first approach
- 📱 Works offline

**Start chatting smarter today!**

---

*Need help? Check out the [User Guide](USER_GUIDE.md) or [Technical Docs](TECHNICAL_DOCUMENTATION.md)*

