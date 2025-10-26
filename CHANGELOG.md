# Changelog

All notable changes to MessageAI are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2025-10-26

### Added - AI Features
- ✨ **Conversation Summarization**: GPT-4 powered summaries with 5 categories (Decisions, Action Items, Blockers, Risks, Next Steps)
- ✨ **Action Item Extraction**: Automatically identifies tasks, assignees, deadlines, and priorities
- ✨ **Decision Tracking**: Captures all decisions made with confidence levels
- ✨ **Smart Search**: Semantic search using natural language queries
- ✨ **Priority Detection**: Multi-dimensional urgency analysis for messages
- 🔧 AI features accessible via sparkles icon in any chat
- 🔧 Health check function to verify AI connectivity
- 🔧 All AI agents use GPT-4 Turbo Preview for speed and cost
- 🔧 JSON mode enabled for reliable structured outputs
- 🔧 Maximum token limits (4096) for comprehensive analysis

### Added - Core Messaging
- 💬 **Text Messaging**: Real-time message delivery via Firestore
- 📷 **Image Sharing**: Upload photos with optional captions
- 🎤 **Voice Messages**: Record and send voice notes up to 60 seconds
- 💭 **Message Reactions**: React with emojis to any message
- ↩️ **Reply Threading**: Reply to specific messages with context
- ➡️ **Forward Messages**: Share messages across conversations
- 🗑️ **Delete Messages**: Delete for yourself or everyone
- 📊 **Message Status**: See when messages are sent, delivered, and read
- ⏰ **Read Receipts**: Know who viewed your messages

### Added - Contacts
- 📇 **Contact Management**: Add, view, and delete contacts
- ➕ **Add by Email**: Find and add users by email address
- 🔄 **Add from Recent**: Add from recent conversation partners
- 💬 **Quick Message**: Message icon for instant chat access
- 👤 **Profile View**: Tap contact to view full profile
- 📱 Dedicated Contacts tab in main navigation

### Added - Group Chats
- 👥 **Group Creation**: Create groups with 2+ participants
- 🎨 **Group Pictures**: Upload and change group photos with auto-save
- 🔤 **Group Icons**: Show first letter of group name as fallback
- 👑 **Group Management**: Creator can add/remove participants
- ℹ️ **Group Info**: View members, change photo, see details
- 📝 **Recent + Contacts**: Select from recent chats or contacts when creating
- 🔢 **Participant Count**: Show (3) participants in group info

### Added - User Profiles
- 🖼️ **Profile Pictures**: Upload, change, remove profile photos
- 📝 **Status Messages**: Set custom status ("What's on your mind?")
- 👤 **User Profile View**: View-only profiles for other users
- ✏️ **Edit Profile**: Change name, photo, and status
- 💾 **Auto-Save**: Pictures save immediately on selection
- 🔙 **Back Navigation**: Clean navigation with circle arrow button

### Added - Privacy & Security
- 🚫 **Block Users**: Block with automatic contact removal and chat deletion
- ⚠️ **Report Users**: Report inappropriate behavior with reason selection
- 🔒 **Privacy Controls**: Toggle online status, read receipts, profile visibility
- 🤖 **Block Auto-Reply**: Blocked users receive "This user has blocked you" message
- 📋 **Blocked Users List**: View and unblock users in settings
- 🔐 **Firestore Trigger**: Firebase Function enforces blocks automatically

### Added - Real-Time Features
- 👀 **Presence System**: Live online/offline status with 15s heartbeat
- ⌨️ **Typing Indicators**: See when others are typing
- 🔔 **In-App Notifications**: Non-intrusive notifications for new messages
- ⚡ **Real-time Sync**: Instant message delivery via Firestore listeners
- 🌐 **Network Awareness**: Graceful handling of connectivity changes

### Added - UI/UX
- 🎨 **Modern Design**: Native iOS interface with dark mode support
- 📱 **Three-Tab Navigation**: Chats, Contacts, Settings
- ✉️ **New Message Screen**: Red arrow button, recent users list
- 🆕 **New Group Screen**: Recent chats (3) + Contacts (4+) sections
- 🎯 **Clean Headers**: Custom headers without blue "Back" buttons
- 📏 **Proper Spacing**: Fixed Settings page spacing with large title
- 🔘 **Consistent Buttons**: Text-only "Add Contact" button
- 💬 **Message Icons**: Blue message icons for quick chat access

### Added - Offline Support
- 💾 **Local Cache**: SwiftData persistence for offline access
- 📤 **Message Queue**: Queue messages when offline
- 🔄 **Auto-Sync**: Automatic sync when connection restored
- 🔁 **Retry Logic**: Exponential backoff with 3 max attempts
- ⏱️ **Status Tracking**: Clear pending/sending/failed states

### Fixed - Critical Bugs
- 🐛 Fixed AI parsing error (Code: 3840) with Unicode sanitization
- 🐛 Fixed online status always showing offline (Timestamp conversion)
- 🐛 Fixed image messages not appearing (initial load processes all documents)
- 🐛 Fixed AI functions returning 0 items (increased token limits)
- 🐛 Fixed profile picture not saving (update User class directly)
- 🐛 Fixed toolbar ambiguity errors in ContactsView
- 🐛 Fixed group icon showing "G" instead of first letter
- 🐛 Fixed priority detection rating everything as low (lowered thresholds)

### Changed
- 🔄 Priority thresholds: HIGH 70+, MEDIUM 20+, LOW 0-19 (was 80+, 40+, 0+)
- 🔄 AI agents: Simplified instructions for better results
- 🔄 Group icons: Show first letter of group name instead of "G"
- 🔄 Navigation: Removed blue "Back" text buttons, kept circle arrows only
- 🔄 Contacts in groups: Real contacts instead of placeholder A, B, C, D
- 🔄 User model: Added `status` field for custom status messages
- 🔄 Conversation model: Added `groupPictureURL` field
- 🔄 Block behavior: Now removes contact and deletes conversation

### Removed
- ❌ Last seen feature (clutter reduction)
- ❌ Blue "Back" text buttons (kept circle arrows)
- ❌ Add/Remove contact icon in UserProfileView (only message icon remains)
- ❌ Verbose logging from AI services (cleaner console)
- ❌ Placeholder contacts (A, B, C, D) in NewGroupChatView

### Security
- 🔒 All API keys in environment variables
- 🔒 Firestore security rules enforced
- 🔒 Storage rules for media access control
- 🔒 Block system with Firebase Function enforcement
- 🔒 Report system for abuse tracking

### Performance
- ⚡ AI token limits maximized (4096) for better results
- ⚡ JSON mode enabled for faster, more reliable parsing
- ⚡ Image compression optimized (60-70% quality)
- ⚡ Presence heartbeat: 15s interval, 20s threshold
- ⚡ Unicode cleaning prevents parsing errors
- ⚡ Initial message load: Process all documents at once

### Documentation
- 📚 Comprehensive README with full feature overview
- 📚 Technical documentation for developers
- 📚 API reference for all services and functions
- 📚 User guide for end users
- 📚 Quick start guide for fast onboarding
- 📚 Product requirements document
- 📚 This changelog!

---

## [0.9.0] - 2025-10-25

### Pre-Release Development

**Foundation Work**:
- Basic messaging infrastructure
- Firebase integration
- Authentication system
- UI component library
- Initial AI experimentation

---

## Upgrade Guide

### From 0.9.0 to 1.0.0

**Breaking Changes**:
- User model now requires `status` field (optional)
- Conversation model now has `groupPictureURL` field
- BlockUserService.blockUser() now requires `conversationID` parameter
- AI functions now return different JSON structure (handled automatically)

**Migration**:
1. Pull latest code
2. Clean build folder
3. Update Firebase Functions: `cd functions && firebase deploy --only functions`
4. Run app - SwiftData will migrate automatically

**New Required Permissions**:
- Microphone access (for voice messages)
- Photo library access (for image sharing)

---

## Future Releases

### v1.1.0 (Planned - Q1 2026)

**Features**:
- Push notifications via APNs
- Message editing (15-minute window)
- Global message search
- iPad optimization
- Landscape mode support

**Improvements**:
- Faster AI response times
- Better image thumbnails
- Improved offline experience
- Contact sync with phone contacts

### v1.2.0 (Planned - Q2 2026)

**Features**:
- Voice calls (1-on-1)
- Video calls (1-on-1)
- File sharing
- Location sharing
- Desktop app (macOS)

**Improvements**:
- End-to-end encryption
- Message threading UI
- @Mentions in groups
- Poll creation

### v2.0.0 (Planned - Q3 2026)

**Major Features**:
- Web application
- Windows/Linux desktop apps
- Enterprise features
- Custom AI models
- Advanced analytics
- API for integrations

---

## Release Notes Format

Each release includes:

**Added**: New features  
**Changed**: Changes to existing functionality  
**Deprecated**: Soon-to-be removed features  
**Removed**: Removed features  
**Fixed**: Bug fixes  
**Security**: Security improvements  
**Performance**: Performance enhancements  

---

## Versioning Policy

**Major Version (X.0.0)**:
- Breaking API changes
- Major feature additions
- Architecture redesigns

**Minor Version (1.X.0)**:
- New features (backwards compatible)
- Significant improvements
- New AI capabilities

**Patch Version (1.0.X)**:
- Bug fixes
- Performance improvements
- UI polish
- Documentation updates

---

## Maintenance Schedule

**Weekly**:
- Monitor Firebase costs
- Review crash reports
- Check AI function logs
- Update dependencies

**Monthly**:
- Security audit
- Performance profiling
- User feedback review
- Plan next release

**Quarterly**:
- Major version planning
- Infrastructure review
- Cost optimization
- Roadmap updates

---

*This changelog is automatically updated with each release.*

