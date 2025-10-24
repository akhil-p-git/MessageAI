# MessageAI 💬🤖

<div align="center">

**A production-ready iOS messaging application with AI-powered insights**

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://www.apple.com/ios)
[![Firebase](https://img.shields.io/badge/Firebase-10.0+-yellow.svg)](https://firebase.google.com)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-green.svg)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

[Features](#-features) • [Installation](#-installation) • [Architecture](#-architecture) • [Screenshots](#-screenshots) • [Contributing](#-contributing)

</div>

---

## 📖 Overview

MessageAI is a **feature-rich iOS messaging application** that combines real-time communication with cutting-edge AI capabilities. Built with SwiftUI and Firebase, it offers a WhatsApp-like experience enhanced with GPT-4 powered insights for team collaboration and productivity.

### 🎯 Key Highlights

- 🤖 **5 AI Agents** powered by GPT-4 for intelligent conversation analysis
- 🎤 **Voice Messages** with instant recording and high-quality playback
- 📴 **Offline-First** architecture with automatic message syncing
- ⚡ **Real-Time** updates for messages, typing, and presence
- 🎨 **Modern UI** with WhatsApp-inspired design and dark mode
- 🔒 **Privacy-Focused** with granular privacy controls

---

## ✨ Features

### Core Messaging

| Feature | Description |
|---------|-------------|
| 💬 **Real-Time Chat** | Instant messaging with Firestore real-time listeners |
| 👥 **Group Chats** | Create and manage group conversations with unlimited participants |
| 💭 **Typing Indicators** | See when others are typing in real-time |
| 🟢 **Online Status** | Live presence indicators with "last seen" timestamps |
| 👁️ **Read Receipts** | WhatsApp-style checkmarks (sent/delivered/read) |
| 💬 **Message Reactions** | React to messages with emojis |
| ↩️ **Reply & Forward** | Quote messages and forward to other chats |
| 🗑️ **Message Deletion** | Delete for yourself or everyone |
| 🔍 **Search** | Find messages within conversations |

### Media & Rich Content

| Feature | Description |
|---------|-------------|
| 📸 **Image Sharing** | Send photos with compression and full-screen preview |
| 🎤 **Voice Messages** | Record and play voice messages with waveform visualization |
| 👤 **Profile Pictures** | Upload and update profile pictures with Firebase Storage |
| 🖼️ **Image Preview** | Preview images before sending |

### AI-Powered Features ⭐

MessageAI includes **5 specialized AI agents** powered by OpenAI GPT-4:

| Agent | Purpose | Use Case |
|-------|---------|----------|
| 🤖 **Thread Summarizer** | Generate concise conversation summaries | Catch up on long conversations quickly |
| ✅ **Action Item Extractor** | Identify tasks and assignments | Track team commitments |
| 🎯 **Decision Tracker** | Log important decisions | Maintain decision history |
| 🔍 **Smart Search** | Semantic search across messages | Find information by meaning, not keywords |
| ⚡ **Priority Detector** | Identify urgent messages | Never miss critical communications |

### Advanced Features

| Feature | Description |
|---------|-------------|
| 🔔 **Push Notifications** | Firebase Cloud Messaging for remote notifications |
| 📱 **Local Notifications** | In-app notification banners |
| 📴 **Offline Support** | Queue messages when offline, auto-sync when online |
| 🌐 **Network Monitoring** | Real-time connectivity status with visual indicators |
| 💾 **Local Persistence** | SwiftData integration for message caching |
| 🎨 **Theme Switching** | Light, Dark, and System themes |
| 🔒 **Privacy Controls** | Control online status visibility |
| 🚫 **Block & Report** | Block users and report inappropriate content |

---

## 🚀 Installation

### Prerequisites

- **Xcode 15.0** or later
- **iOS 17.0+** deployment target
- **Firebase Account** ([Create one here](https://console.firebase.google.com/))
- **OpenAI API Key** ([Get one here](https://platform.openai.com/api-keys))

### Step 1: Clone the Repository

```bash
git clone https://github.com/akhil-p-git/MessageAI.git
cd MessageAI
```

### Step 2: Firebase Setup

1. **Create a Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Click "Add project" and follow the setup wizard

2. **Add iOS App to Firebase**
   - Click "Add app" → iOS
   - Enter your bundle ID: `com.yourname.MessageAI`
   - Download `GoogleService-Info.plist`
   - Replace the existing file in the project root

3. **Enable Firebase Services**
   - **Authentication**: Enable Email/Password provider
   - **Firestore Database**: Create database in production mode
   - **Storage**: Enable Firebase Storage
   - **Cloud Functions**: Enable for AI features

4. **Deploy Security Rules**
   ```bash
   # Install Firebase CLI
   npm install -g firebase-tools
   
   # Login to Firebase
   firebase login
   
   # Initialize project
   firebase init
   
   # Deploy rules
   firebase deploy --only firestore:rules,storage:rules
   ```

### Step 3: AI Features Setup

1. **Get OpenAI API Key**
   - Visit [OpenAI Platform](https://platform.openai.com/api-keys)
   - Create a new API key

2. **Configure Cloud Functions**
   ```bash
   cd functions
   npm install
   
   # Create .env file
   echo "OPENAI_API_KEY=your_api_key_here" > .env
   
   # Deploy functions
   firebase deploy --only functions
   ```

### Step 4: Open and Run

```bash
# Open project in Xcode
open MessageAI.xcodeproj

# Build and run (⌘R)
```

---

## 🏗️ Architecture

MessageAI follows **MVVM (Model-View-ViewModel)** architecture with a clean separation of concerns.

### Project Structure

```
MessageAI/
├── Models/                    # Data models
│   ├── User.swift            # User model (SwiftData + Firestore)
│   ├── Conversation.swift    # Conversation model
│   ├── Message.swift         # Message model with offline support
│   └── AIModels.swift        # AI feature data structures
│
├── Views/                     # SwiftUI views
│   ├── Auth/                 # Authentication screens
│   ├── Chat/                 # Chat interface
│   ├── AI/                   # AI feature views
│   ├── Settings/             # Settings screens
│   └── Components/           # Reusable UI components
│
├── ViewModels/               # State management
│   └── AuthViewModel.swift   # Authentication logic
│
├── Services/                 # Business logic layer
│   ├── AuthService.swift     # User authentication
│   ├── ConversationService.swift  # Chat operations
│   ├── MediaService.swift    # Image/voice handling
│   ├── AIService.swift       # AI feature integration
│   ├── NetworkMonitor.swift  # Connectivity monitoring
│   ├── PresenceService.swift # Online status tracking
│   ├── NotificationManager.swift  # Push notifications
│   └── [15+ specialized services]
│
└── MessageAIApp.swift        # App entry point
```

### Key Services

| Service | Responsibility |
|---------|---------------|
| `AuthService` | Firebase Authentication, user management |
| `ConversationService` | Chat creation, participant management |
| `MediaService` | Image/voice upload to Firebase Storage |
| `AIService` | Communication with Firebase Cloud Functions |
| `NetworkMonitor` | Real-time network connectivity tracking |
| `MessageSyncService` | Offline message queue and sync |
| `PresenceService` | Online status with heartbeat mechanism |
| `TypingIndicatorService` | Real-time typing status |
| `NotificationManager` | Local and push notifications |
| `ThemeManager` | App-wide theme management |

### Data Flow

```
User Action → View → ViewModel → Service → Firebase
                ↓                    ↓
            UI Update ← Published State ← Real-time Listener
```

### Offline-First Architecture

1. **Write**: Messages saved to SwiftData immediately (optimistic UI)
2. **Sync**: Background task uploads to Firestore when online
3. **Read**: Local SwiftData cache + Firestore real-time listeners
4. **Conflict Resolution**: Server timestamp wins

---

## 📱 Screenshots

> **Note**: Add screenshots here showing:
> - Login/Signup screens
> - Chat interface (1-on-1 and group)
> - AI features panel
> - Voice message recording
> - Settings screens
> - Dark mode

---

## 🧪 Testing

### Manual Testing Checklist

#### Authentication
- [ ] Sign up with new account
- [ ] Sign in with existing account
- [ ] Sign out
- [ ] Error handling (wrong password, etc.)

#### Messaging
- [ ] Send text message
- [ ] Send image
- [ ] Record and send voice message
- [ ] React to message
- [ ] Reply to message
- [ ] Delete message (for me / for everyone)
- [ ] Forward message

#### Real-Time Features
- [ ] Typing indicator appears when other user types
- [ ] Online status updates immediately
- [ ] Read receipts update in real-time
- [ ] Messages appear instantly

#### AI Features
- [ ] Generate conversation summary
- [ ] Extract action items
- [ ] Track decisions
- [ ] Smart search
- [ ] Priority detection

#### Offline Mode
- [ ] Send message while offline
- [ ] Message queues locally
- [ ] Auto-sync when online
- [ ] Offline indicator shows

---

## 🛠️ Tech Stack

### Frontend
- **SwiftUI** - Declarative UI framework
- **SwiftData** - Local persistence and caching
- **Combine** - Reactive programming
- **AVFoundation** - Audio recording/playback

### Backend
- **Firebase Authentication** - User management
- **Firestore** - Real-time NoSQL database
- **Firebase Storage** - Media file storage
- **Cloud Functions** - Serverless backend (Node.js)
- **Firebase Cloud Messaging** - Push notifications

### AI/ML
- **OpenAI GPT-4** - Natural language processing
- **Custom AI Agents** - Specialized task-specific prompts

### Tools & Libraries
- **Network Framework** - Connectivity monitoring
- **PhotosUI** - Image picker
- **UserNotifications** - Local notifications

---

## 🎨 Design Philosophy

MessageAI follows **Apple's Human Interface Guidelines** with a focus on:

1. **Clarity**: Clean, readable interface with clear visual hierarchy
2. **Deference**: Content-first design, UI elements don't compete
3. **Depth**: Layers and motion provide context and meaning
4. **Consistency**: Familiar patterns from iOS and WhatsApp
5. **Accessibility**: Support for Dynamic Type, VoiceOver, Dark Mode

### UI Inspiration

- **WhatsApp**: Message bubbles, timestamps, read receipts
- **iMessage**: Reactions, reply threading
- **Slack**: AI insights, search functionality
- **Telegram**: Voice messages, media handling

---

## 🔐 Security & Privacy

### Firebase Security Rules

- **Firestore**: Users can only read/write their own conversations
- **Storage**: Users can only upload to their own profile picture path
- **Authentication**: Email/password with Firebase Auth

### Privacy Features

- **Online Status Control**: Hide your online status from others
- **Block Users**: Prevent specific users from contacting you
- **Local Data**: Messages cached locally with SwiftData
- **No Third-Party Analytics**: Your data stays private

---

## 🚦 Known Issues & Limitations

### Current Limitations

1. **AI Features**: Require active internet connection
2. **Voice Messages**: Maximum 60 seconds per recording
3. **Group Chats**: No admin roles or permissions yet
4. **Media**: Images compressed to 1MB for faster uploads

### Planned Improvements

- [ ] End-to-end encryption
- [ ] Video calls
- [ ] Message translation
- [ ] GIF support
- [ ] Stories/Status updates
- [ ] Location sharing

---

## 📚 Documentation

- [**ARCHITECTURE.md**](ARCHITECTURE.md) - Detailed architecture guide
- [**SETUP.md**](SETUP.md) - Complete setup instructions
- [**PROJECT_ANALYSIS.md**](PROJECT_ANALYSIS.md) - Feature analysis and grading rubric
- [**CONTRIBUTING.md**](CONTRIBUTING.md) - Contribution guidelines

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/AmazingFeature`)
3. **Commit** your changes (`git commit -m 'Add some AmazingFeature'`)
4. **Push** to the branch (`git push origin feature/AmazingFeature`)
5. **Open** a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Author

**Akhil P**

- GitHub: [@akhil-p-git](https://github.com/akhil-p-git)
- Email: your.email@example.com

---

## 🙏 Acknowledgments

- **Firebase** - Backend infrastructure and real-time database
- **OpenAI** - GPT-4 API for AI features
- **Apple** - SwiftUI framework and iOS platform
- **WhatsApp** - UI/UX inspiration
- **The Swift Community** - Countless tutorials and resources

---

## 📊 Project Stats

- **Lines of Code**: ~15,000+
- **Services**: 15+
- **Views**: 40+
- **Models**: 4
- **AI Agents**: 5
- **Development Time**: 3 weeks
- **Firebase Functions**: 5

---

## 🌟 Star History

If you find this project useful, please consider giving it a star! ⭐

---

<div align="center">

**Made with ❤️ and SwiftUI**

[⬆ Back to Top](#messageai-)

</div>
