# MessageAI

A modern iOS messaging application built with SwiftUI and Firebase, featuring real-time chat capabilities and AI-powered features.

## Features

- 🔐 **Authentication**: Email/password authentication with Firebase Auth
- 💬 **Real-time Messaging**: Instant messaging powered by Firebase Firestore
- 👤 **User Profiles**: Custom user profiles with online status tracking
- 🎨 **Modern UI**: Beautiful SwiftUI interface with gradient designs
- 📱 **iOS Native**: Built with SwiftUI for iOS 17+
- 🔔 **Push Notifications**: FCM token support for push notifications
- 💾 **Local Persistence**: SwiftData integration for offline support

## Tech Stack

- **Frontend**: SwiftUI
- **Backend**: Firebase (Authentication, Firestore)
- **Local Storage**: SwiftData
- **Architecture**: MVVM (Model-View-ViewModel)
- **Minimum iOS Version**: iOS 17.0+

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

- [ ] Real-time messaging functionality
- [ ] Group chats
- [ ] Media sharing (images, videos)
- [ ] Voice messages
- [ ] AI-powered features
- [ ] Push notifications
- [ ] User search
- [ ] Profile customization
- [ ] Dark mode support
- [ ] End-to-end encryption

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

