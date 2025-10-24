# MessageAI Setup Guide

Complete step-by-step instructions to get MessageAI running on your machine.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Clone Repository](#clone-repository)
3. [Firebase Setup](#firebase-setup)
4. [OpenAI Setup](#openai-setup)
5. [Xcode Configuration](#xcode-configuration)
6. [Running the App](#running-the-app)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

- **macOS** 13.0 (Ventura) or later
- **Xcode** 15.0 or later ([Download](https://developer.apple.com/xcode/))
- **Node.js** 18+ and npm ([Download](https://nodejs.org/))
- **Firebase CLI** ([Install](https://firebase.google.com/docs/cli))
- **Git** (pre-installed on macOS)

### Required Accounts

- **Apple Developer Account** (free tier is fine)
- **Firebase Account** ([Sign up](https://console.firebase.google.com/))
- **OpenAI Account** with API access ([Sign up](https://platform.openai.com/))

### Check Your Setup

```bash
# Check Xcode
xcodebuild -version
# Should show: Xcode 15.0 or later

# Check Node.js
node --version
# Should show: v18.0.0 or later

# Check npm
npm --version
# Should show: 9.0.0 or later

# Check Git
git --version
# Should show: git version 2.x.x
```

---

## Clone Repository

### 1. Clone the Project

```bash
# Clone via HTTPS
git clone https://github.com/akhil-p-git/MessageAI.git

# Or clone via SSH (if you have SSH keys set up)
git clone git@github.com:akhil-p-git/MessageAI.git

# Navigate to project directory
cd MessageAI
```

### 2. Verify Project Structure

```bash
ls -la
# You should see:
# - MessageAI/ (Xcode project folder)
# - functions/ (Firebase Functions)
# - firestore.rules
# - storage.rules
# - README.md
# - etc.
```

---

## Firebase Setup

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"**
3. Enter project name: `MessageAI` (or your preferred name)
4. Disable Google Analytics (optional, not needed for this app)
5. Click **"Create project"**
6. Wait for project creation (~30 seconds)

### 2. Add iOS App to Firebase

1. In Firebase Console, click **"Add app"** → **iOS**
2. Enter iOS bundle ID: `com.yourname.MessageAI`
   - ⚠️ **Important**: Use a unique bundle ID (e.g., `com.johndoe.MessageAI`)
3. Enter app nickname: `MessageAI` (optional)
4. Leave App Store ID blank
5. Click **"Register app"**

### 3. Download Configuration File

1. Download `GoogleService-Info.plist`
2. **Replace** the existing file in your project:
   ```bash
   # From your Downloads folder
   cp ~/Downloads/GoogleService-Info.plist MessageAI/MessageAI/GoogleService-Info.plist
   ```
3. ⚠️ **Important**: Never commit this file to a public repository!

### 4. Enable Firebase Services

#### A. Enable Authentication

1. In Firebase Console, go to **Authentication** → **Sign-in method**
2. Click **"Email/Password"**
3. Toggle **"Enable"**
4. Click **"Save"**

#### B. Create Firestore Database

1. Go to **Firestore Database** → **"Create database"**
2. Select **"Start in production mode"**
3. Choose a location (e.g., `us-central1`)
4. Click **"Enable"**

#### C. Enable Firebase Storage

1. Go to **Storage** → **"Get started"**
2. Click **"Next"** (use default rules)
3. Choose same location as Firestore
4. Click **"Done"**

#### D. Enable Cloud Functions

1. Go to **Functions** → **"Get started"**
2. Click **"Upgrade project"** (requires Blaze plan)
   - ⚠️ **Note**: Blaze plan is pay-as-you-go, but includes generous free tier
   - Free tier: 2M invocations/month, 400K GB-seconds/month
3. Click **"Continue"**

### 5. Deploy Security Rules

```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in project directory
cd /path/to/MessageAI
firebase init

# Select:
# - Firestore
# - Storage
# - Functions

# When prompted:
# - Use existing project: Select your MessageAI project
# - Firestore rules file: firestore.rules (already exists)
# - Firestore indexes file: firestore.indexes.json (create)
# - Storage rules file: storage.rules (already exists)
# - Functions language: JavaScript
# - ESLint: No
# - Install dependencies: Yes

# Deploy rules
firebase deploy --only firestore:rules,storage:rules
```

### 6. Set Up Cloud Functions

```bash
cd functions

# Install dependencies
npm install

# Install additional packages
npm install openai dotenv

# Create .env file for OpenAI API key
touch .env
```

---

## OpenAI Setup

### 1. Get API Key

1. Go to [OpenAI Platform](https://platform.openai.com/)
2. Sign up or log in
3. Go to **API Keys** → **"Create new secret key"**
4. Name it: `MessageAI`
5. Copy the key (starts with `sk-proj-...`)
   - ⚠️ **Important**: Save this key! You won't be able to see it again.

### 2. Add API Key to Functions

```bash
cd functions

# Edit .env file
nano .env

# Add this line (replace with your actual key):
OPENAI_API_KEY=sk-proj-your-actual-key-here

# Save and exit (Ctrl+X, then Y, then Enter)
```

### 3. Deploy Cloud Functions

```bash
# Still in functions/ directory
firebase deploy --only functions

# This will deploy 5 functions:
# - summarizeThread
# - extractActionItems
# - trackDecisions
# - smartSearch
# - detectPriority

# Deployment takes ~2-3 minutes
```

### 4. Verify Deployment

```bash
# Check deployed functions
firebase functions:list

# You should see:
# ✓ summarizeThread
# ✓ extractActionItems
# ✓ trackDecisions
# ✓ smartSearch
# ✓ detectPriority
```

---

## Xcode Configuration

### 1. Open Project

```bash
cd /path/to/MessageAI
open MessageAI.xcodeproj
```

### 2. Update Bundle Identifier

1. In Xcode, select **MessageAI** project in navigator
2. Select **MessageAI** target
3. Go to **"Signing & Capabilities"** tab
4. Change **Bundle Identifier** to match Firebase:
   - Example: `com.johndoe.MessageAI`
5. Select your **Team** (Apple Developer account)
6. Xcode will automatically handle signing

### 3. Verify GoogleService-Info.plist

1. In Xcode navigator, find `GoogleService-Info.plist`
2. Make sure it's in the **MessageAI** folder (not root)
3. Check **Target Membership**: MessageAI should be checked

### 4. Configure Capabilities

The project already has these capabilities configured:
- ✓ Push Notifications
- ✓ Background Modes (Remote notifications)
- ✓ App Groups (optional, for extensions)

If missing, add them:
1. Select **MessageAI** target
2. Go to **"Signing & Capabilities"**
3. Click **"+ Capability"**
4. Add **"Push Notifications"**
5. Add **"Background Modes"** → Enable **"Remote notifications"**

### 5. Update App Transport Security (if needed)

The project's `Info.plist` should already allow Firebase connections.

If you encounter network errors, add this to `Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

⚠️ **Note**: Only for development. Remove for production.

---

## Running the App

### 1. Select Simulator or Device

In Xcode toolbar:
- For Simulator: Select **iPhone 15 Pro** (or any iOS 17+ simulator)
- For Physical Device: Connect your iPhone and select it

### 2. Build and Run

```bash
# In Xcode, press:
⌘ + R

# Or click the "Play" button in toolbar
```

### 3. First Launch

1. App will launch to **Login** screen
2. Click **"Sign Up"**
3. Enter:
   - Email: `test@example.com`
   - Password: `password123`
   - Display Name: `Test User`
4. Click **"Sign Up"**
5. You'll be taken to the **Conversation List**

### 4. Test Basic Features

#### Create a Second User (for testing)

1. Sign out (Settings → Sign Out)
2. Sign up with different email: `test2@example.com`
3. Now you have two test users!

#### Test Messaging

1. Sign in as User 1
2. Click **"+"** → **"New Chat"**
3. Search for User 2's email
4. Send a message
5. Sign in as User 2 on another device/simulator
6. See message appear in real-time!

#### Test AI Features

1. Have a conversation with several messages
2. Tap **✨ sparkles icon** in chat
3. Try each AI feature:
   - **Summary**: Generate conversation summary
   - **Action Items**: Extract tasks
   - **Decisions**: Track decisions
   - **Smart Search**: Semantic search
   - **Priority**: Detect urgent messages

---

## Troubleshooting

### Common Issues

#### 1. "No such module 'FirebaseAuth'"

**Solution**: Dependencies not resolved

```bash
# In Xcode:
# File → Packages → Reset Package Caches
# File → Packages → Resolve Package Versions

# Wait for packages to download (~2 minutes)
```

#### 2. "GoogleService-Info.plist not found"

**Solution**: File not in correct location

1. Drag `GoogleService-Info.plist` into Xcode
2. Ensure it's in **MessageAI** folder
3. Check **"Copy items if needed"**
4. Select **MessageAI** target

#### 3. "Signing requires a development team"

**Solution**: Add Apple Developer account

1. Xcode → Settings → Accounts
2. Click **"+"** → Add Apple ID
3. Sign in with your Apple ID
4. Go back to project → Signing & Capabilities
5. Select your team

#### 4. "Firebase Functions not working"

**Solution**: Check deployment

```bash
# Verify functions are deployed
firebase functions:list

# Check function logs
firebase functions:log

# Redeploy if needed
cd functions
firebase deploy --only functions
```

#### 5. "OpenAI API Error"

**Solution**: Check API key

```bash
# Verify .env file exists
cd functions
cat .env

# Should show:
# OPENAI_API_KEY=sk-proj-...

# Redeploy functions
firebase deploy --only functions
```

#### 6. "Network error" or "Permission denied"

**Solution**: Check Firestore rules

```bash
# Verify rules are deployed
firebase deploy --only firestore:rules,storage:rules

# Check rules in Firebase Console:
# Firestore Database → Rules
# Storage → Rules
```

#### 7. App crashes on launch

**Solution**: Check console logs

1. In Xcode, open **Console** (⌘ + Shift + C)
2. Look for error messages
3. Common issues:
   - Missing GoogleService-Info.plist
   - Invalid Firebase configuration
   - Network connectivity issues

#### 8. "Voice messages not recording"

**Solution**: Grant microphone permission

1. Settings → Privacy & Security → Microphone
2. Enable for MessageAI
3. Restart app

#### 9. "Images not uploading"

**Solution**: Grant photo library permission

1. Settings → Privacy & Security → Photos
2. Enable for MessageAI
3. Restart app

---

## Verification Checklist

Before considering setup complete, verify:

- [ ] App launches without errors
- [ ] Can sign up new user
- [ ] Can sign in with existing user
- [ ] Can create 1-on-1 conversation
- [ ] Can send text message
- [ ] Can send image
- [ ] Can record voice message
- [ ] Real-time updates work (typing, online status)
- [ ] AI features accessible (sparkles button)
- [ ] At least one AI feature works (try Summary)
- [ ] Offline mode works (airplane mode test)
- [ ] Push notifications permission requested

---

## Next Steps

### Development

- Read [ARCHITECTURE.md](ARCHITECTURE.md) for technical details
- Read [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines
- Explore the codebase and make changes!

### Testing

- Test on physical device (not just simulator)
- Test with multiple users
- Test offline scenarios
- Test all AI features

### Deployment

- Update app icon and splash screen
- Configure proper Firebase security rules for production
- Set up App Store Connect
- Submit for review

---

## Getting Help

### Resources

- **Firebase Documentation**: https://firebase.google.com/docs
- **SwiftUI Documentation**: https://developer.apple.com/documentation/swiftui
- **OpenAI API Documentation**: https://platform.openai.com/docs

### Support

- **GitHub Issues**: [Create an issue](https://github.com/akhil-p-git/MessageAI/issues)
- **Email**: your.email@example.com

---

## Success! 🎉

If you've completed all steps, you now have a fully functional MessageAI installation!

Try these next:
1. Create a group chat with multiple users
2. Test all 5 AI features
3. Customize the UI to your liking
4. Add new features!

---

**Last Updated**: October 24, 2025  
**Version**: 1.0.0

