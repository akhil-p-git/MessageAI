# MessageAI

A **production-ready iOS messaging application** built with SwiftUI and Firebase, featuring real-time chat capabilities, AI-powered insights, voice messages, and comprehensive offline support.

## ✨ Features

### **Core Messaging**
- 🔐 **Authentication**: Email/password authentication with Firebase Auth
- 💬 **Real-time Messaging**: Instant messaging powered by Firebase Firestore
- 👥 **Group Chats**: Create and manage group conversations with multiple participants
- 💭 **Typing Indicators**: See when someone is typing in real-time
- 🟢 **Online Status**: Live presence indicators with privacy controls
- 👁️ **Read Receipts**: Single/double checkmarks with read count for group chats
- 💬 **Message Reactions**: React to messages with emojis
- ↩️ **Reply & Forward**: Quote messages and forward to other chats
- 🗑️ **Delete Messages**: Delete for yourself or everyone
- 🔍 **Search Messages**: Find messages within conversations

### **Media & Rich Content**
- 📸 **Image Sharing**: Send and receive photos with full-screen preview
- 🎤 **Voice Messages**: Record and play voice messages with real-time recording
- 🖼️ **Image Preview**: Preview images before sending
- 👤 **Profile Pictures**: Upload and update profile pictures

### **AI-Powered Features** ⭐
- 🤖 **AI Summary**: GPT-4 powered conversation summarization
- ✅ **Action Items**: Automatically extract tasks from conversations
- 🎯 **Decision Tracking**: Track team decisions made in chats
- 🔍 **Smart Search**: Semantic search across conversation history
- ⚡ **Priority Detection**: Identify urgent messages automatically

### **Advanced Features**
- 🔔 **Push Notifications**: Firebase Cloud Messaging integration
- 📱 **Local Notifications**: In-app notification banners
- 📴 **Offline Support**: Message queuing and sync when offline
- 🌐 **Network Monitoring**: Real-time connectivity status
- 💾 **Local Persistence**: SwiftData integration for message caching
- 🎨 **Theme Switching**: Light, Dark, and System themes
- 🔒 **Privacy Controls**: Control online status visibility
- 🚫 **Block & Report**: Block users and report inappropriate content

## Tech Stack

- **Frontend**: SwiftUI (iOS 17+)
- **Backend**: Firebase (Authentication, Firestore, Storage, Functions, Cloud Messaging)
- **AI/ML**: OpenAI GPT-4 (via Firebase Cloud Functions)
- **Local Storage**: SwiftData
- **Architecture**: MVVM (Model-View-ViewModel)
- **Minimum iOS Version**: iOS 17.0+

## 🏗️ Architecture

### **Services** (15+ specialized services)
- `AuthService` - User authentication and management
- `ConversationService` - Chat conversation handling
- `MediaService` - Image and media uploads
- `AudioRecorderService` - Voice message recording
- `AudioPlayerService` - Voice message playback
- `AIService` - AI features via Firebase Functions
- `NotificationManager` - Push and local notifications
- `NetworkMonitor` - Internet connectivity monitoring
- `MessageSyncService` - Offline message queuing
- `TypingIndicatorService` - Real-time typing status
- `PresenceService` - Online status tracking
- `ReactionService` - Message reactions
- `DeleteMessageService` - Message deletion
- `BlockUserService` - User blocking
- `ThemeManager` - App theme management

### **Models**
- `User` - User data with SwiftData + Firestore sync
- `Conversation` - Chat conversations with metadata
- `Message` - Chat messages with offline support
- `AIModels` - AI feature data structures

### **Views** (20+ reusable components)
- Auth views (Login, SignUp)
- Chat views (ChatView, ConversationListView, NewChatView)
- AI views (Summary, Action Items, Decisions, Smart Search)
- Component views (Message bubbles, Reactions, Typing indicators)
- Settings views (Privacy, Appearance, Notifications)

## Project Structure

```
MessageAI/
├── Models/
│   └── User.swift              # SwiftData user model with Firestore compatibility
├── Services/
│   └── AuthService.swift       # Firebase authentication service
├── ViewModels/
│   └── AuthViewModel.swift     # Authentication state management
├── Views/
│   ├── Auth/
│   │   ├── LoginView.swift    # Login screen
│   │   └── SignUpView.swift   # Sign up screen
│   ├── MainTabView.swift      # Main tab navigation
│   └── RootView.swift         # Root view coordinator
└── MessageAIApp.swift         # App entry point
```

## Getting Started

### Prerequisites

- Xcode 15.0 or later
- iOS 17.0+ deployment target
- CocoaPods or Swift Package Manager
- Firebase account

### Installation

1. Clone the repository:
```bash
git clone https://github.com/akhil-p-git/MessageAI.git
cd MessageAI
```

2. Install dependencies:
   - The project uses Swift Package Manager for Firebase dependencies
   - Dependencies should automatically resolve when opening the project in Xcode

3. Configure Firebase:
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Add an iOS app to your Firebase project
   - Download the `GoogleService-Info.plist` file
   - Replace the existing `GoogleService-Info.plist` in the project

4. Open the project:
```bash
open MessageAI.xcodeproj
```

5. Build and run the project in Xcode (⌘R)

## Firebase Setup

### Authentication
1. Enable Email/Password authentication in Firebase Console
2. Go to Authentication → Sign-in method
3. Enable "Email/Password" provider

### Firestore Database
1. Create a Firestore database in your Firebase project
2. Start in production mode or test mode
3. Set up security rules (example):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    match /messages/{messageId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Architecture

### MVVM Pattern
- **Models**: Data structures (User)
- **Views**: SwiftUI views (LoginView, SignUpView, etc.)
- **ViewModels**: Business logic and state management (AuthViewModel)
- **Services**: Backend communication (AuthService)

### Key Components

#### AuthService
Singleton service handling all Firebase authentication operations:
- User sign up/sign in/sign out
- User document management in Firestore
- Online status tracking
- Error handling and mapping

#### AuthViewModel
ObservableObject managing authentication UI state:
- Published properties for reactive UI updates
- Async/await for clean asynchronous code
- Form validation and error handling

#### User Model
SwiftData model with Firestore compatibility:
- Unique ID attribute for data integrity
- Bidirectional conversion (SwiftData ↔ Firestore)
- Support for optional fields

## Usage

### Sign Up
```swift
await viewModel.signUp(
    email: "user@example.com",
    password: "password123",
    displayName: "John Doe"
)
```

### Sign In
```swift
await viewModel.signIn(
    email: "user@example.com",
    password: "password123"
)
```

### Sign Out
```swift
viewModel.signOut()
```

## Error Handling

The app includes comprehensive error handling with custom error types:
- `userNotFound`: User doesn't exist
- `invalidCredentials`: Wrong email/password
- `emailAlreadyInUse`: Email already registered
- `weakPassword`: Password too short
- `networkError`: Network connectivity issues

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Roadmap

### ✅ **Completed Features**
- [x] Real-time messaging functionality
- [x] Group chats
- [x] Media sharing (images, voice messages)
- [x] AI-powered features (5 agents!)
- [x] Push notifications
- [x] User search
- [x] Profile customization
- [x] Dark mode support
- [x] Offline support with message queuing
- [x] Read receipts and typing indicators
- [x] Message reactions
- [x] Privacy controls

### 🚀 **Future Enhancements**
- [ ] End-to-end encryption
- [ ] Video calls
- [ ] Stories/Status updates
- [ ] Message polls
- [ ] Location sharing
- [ ] GIF support
- [ ] Stickers
- [ ] Message translation

## License

This project is available for personal and educational use.

## Contact

Akhil P - [@akhil-p-git](https://github.com/akhil-p-git)

Project Link: [https://github.com/akhil-p-git/MessageAI](https://github.com/akhil-p-git/MessageAI)

## Acknowledgments

- [Firebase](https://firebase.google.com/) - Backend infrastructure
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - UI framework
- [Apple Developer Documentation](https://developer.apple.com/documentation/) - Development resources

---

Made with ❤️ and SwiftUI

