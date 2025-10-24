# Contributing to MessageAI

Thank you for your interest in contributing to MessageAI! This document provides guidelines and instructions for contributing.

---

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Workflow](#development-workflow)
4. [Coding Standards](#coding-standards)
5. [Commit Guidelines](#commit-guidelines)
6. [Pull Request Process](#pull-request-process)
7. [Testing](#testing)
8. [Documentation](#documentation)

---

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors.

### Our Standards

**Positive behavior includes:**
- Using welcoming and inclusive language
- Being respectful of differing viewpoints
- Gracefully accepting constructive criticism
- Focusing on what is best for the community

**Unacceptable behavior includes:**
- Trolling, insulting comments, or personal attacks
- Public or private harassment
- Publishing others' private information
- Other conduct which could reasonably be considered inappropriate

---

## Getting Started

### Prerequisites

Before contributing, make sure you have:
- Completed the [SETUP.md](SETUP.md) instructions
- Read the [ARCHITECTURE.md](ARCHITECTURE.md) documentation
- Familiarized yourself with the codebase

### Finding Issues to Work On

1. **Good First Issues**: Look for issues labeled `good-first-issue`
2. **Help Wanted**: Check issues labeled `help-wanted`
3. **Feature Requests**: Browse issues labeled `enhancement`
4. **Bug Reports**: Check issues labeled `bug`

### Claiming an Issue

1. Comment on the issue: "I'd like to work on this"
2. Wait for maintainer approval
3. Fork the repository
4. Start working!

---

## Development Workflow

### 1. Fork and Clone

```bash
# Fork the repository on GitHub (click "Fork" button)

# Clone your fork
git clone https://github.com/YOUR_USERNAME/MessageAI.git
cd MessageAI

# Add upstream remote
git remote add upstream https://github.com/akhil-p-git/MessageAI.git
```

### 2. Create a Branch

```bash
# Update your main branch
git checkout main
git pull upstream main

# Create a feature branch
git checkout -b feature/your-feature-name

# Or for bug fixes
git checkout -b fix/bug-description
```

**Branch Naming Convention:**
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring
- `test/` - Test additions/updates

### 3. Make Changes

- Write clean, readable code
- Follow the [Coding Standards](#coding-standards)
- Add comments for complex logic
- Update documentation if needed

### 4. Test Your Changes

```bash
# Run the app in simulator
# Test all affected features
# Verify no regressions

# Test on physical device if possible
```

### 5. Commit Your Changes

```bash
# Stage your changes
git add .

# Commit with descriptive message
git commit -m "feat: add voice message playback speed control"

# Push to your fork
git push origin feature/your-feature-name
```

### 6. Create Pull Request

1. Go to your fork on GitHub
2. Click **"Pull Request"**
3. Select **base: main** ← **compare: your-branch**
4. Fill out the PR template
5. Click **"Create Pull Request"**

---

## Coding Standards

### Swift Style Guide

Follow [Swift.org API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)

#### Naming Conventions

```swift
// Classes, Structs, Enums: PascalCase
class MessageService { }
struct User { }
enum MessageType { }

// Variables, Functions: camelCase
var messageText: String
func sendMessage() { }

// Constants: camelCase
let maxMessageLength = 500

// Private properties: prefix with underscore (optional)
private var _cache: [String: Any] = [:]
```

#### Code Organization

```swift
// MARK: - Lifecycle
override func viewDidLoad() { }

// MARK: - Public API
func sendMessage() { }

// MARK: - Private Methods
private func uploadToFirestore() { }

// MARK: - IBActions
@IBAction func buttonTapped() { }
```

#### SwiftUI Best Practices

```swift
// Extract complex views into separate structs
struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        // Simple, focused view
    }
}

// Use @StateObject for owned objects
@StateObject private var viewModel = ChatViewModel()

// Use @ObservedObject for passed objects
@ObservedObject var authViewModel: AuthViewModel

// Use @State for simple local state
@State private var messageText = ""

// Use @Binding for two-way binding
@Binding var isPresented: Bool
```

#### Error Handling

```swift
// Use Result type for async operations
func fetchUser() async -> Result<User, Error> {
    do {
        let user = try await service.getUser()
        return .success(user)
    } catch {
        return .failure(error)
    }
}

// Use throws for synchronous operations
func validateEmail(_ email: String) throws {
    guard email.contains("@") else {
        throw ValidationError.invalidEmail
    }
}

// Always log errors
catch {
    print("❌ Error fetching user: \(error.localizedDescription)")
}
```

### Firebase Best Practices

```swift
// Always check authentication
guard let currentUser = Auth.auth().currentUser else {
    throw AuthError.notAuthenticated
}

// Use batch writes for multiple updates
let batch = db.batch()
batch.setData(data1, forDocument: ref1)
batch.setData(data2, forDocument: ref2)
try await batch.commit()

// Always remove listeners
var listener: ListenerRegistration?

func startListening() {
    listener = db.collection("messages").addSnapshotListener { ... }
}

deinit {
    listener?.remove()
}
```

### Comments

```swift
// Use comments for WHY, not WHAT
// ❌ Bad: Increment counter
counter += 1

// ✅ Good: Track retry attempts for exponential backoff
retryCount += 1

// Use doc comments for public APIs
/// Sends a message to the specified conversation.
///
/// - Parameters:
///   - message: The message to send
///   - conversationID: The target conversation ID
/// - Returns: The sent message with updated status
/// - Throws: `NetworkError` if upload fails
func sendMessage(_ message: Message, to conversationID: String) async throws -> Message {
    // Implementation
}
```

---

## Commit Guidelines

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Examples

```bash
# Feature
git commit -m "feat(chat): add voice message playback speed control"

# Bug fix
git commit -m "fix(auth): resolve sign-in crash on iOS 17"

# Documentation
git commit -m "docs(readme): update installation instructions"

# Refactor
git commit -m "refactor(services): extract common Firebase logic"

# Multiple changes
git commit -m "feat(chat): add message reactions

- Add reaction picker UI
- Implement Firestore reaction storage
- Add real-time reaction updates
- Update message bubble to show reactions

Closes #123"
```

### Commit Best Practices

- **One logical change per commit**
- **Write descriptive messages**
- **Reference issues**: `Closes #123` or `Fixes #456`
- **Keep commits small**: Easier to review and revert
- **Test before committing**: Ensure code compiles

---

## Pull Request Process

### Before Submitting

- [ ] Code compiles without errors
- [ ] All tests pass
- [ ] No new warnings
- [ ] Code follows style guide
- [ ] Documentation updated (if needed)
- [ ] Tested on simulator
- [ ] Tested on physical device (if possible)

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tested on simulator
- [ ] Tested on physical device
- [ ] Added/updated tests

## Screenshots (if applicable)
Add screenshots here

## Related Issues
Closes #123
```

### Review Process

1. **Automated Checks**: CI/CD runs (if configured)
2. **Code Review**: Maintainer reviews code
3. **Feedback**: Address any requested changes
4. **Approval**: Maintainer approves PR
5. **Merge**: PR is merged into main branch

### Addressing Feedback

```bash
# Make requested changes
# Commit changes
git add .
git commit -m "fix: address review feedback"

# Push to your branch
git push origin feature/your-feature-name

# PR will automatically update
```

---

## Testing

### Manual Testing

Before submitting a PR, test these scenarios:

#### Authentication
- [ ] Sign up with new account
- [ ] Sign in with existing account
- [ ] Sign out
- [ ] Error handling (wrong password, etc.)

#### Messaging
- [ ] Send text message
- [ ] Send image
- [ ] Send voice message
- [ ] Message appears in real-time
- [ ] Read receipts update
- [ ] Typing indicator works

#### Offline Mode
- [ ] Enable airplane mode
- [ ] Send message
- [ ] Disable airplane mode
- [ ] Message syncs automatically

#### AI Features (if modified)
- [ ] Generate summary
- [ ] Extract action items
- [ ] Track decisions
- [ ] Smart search
- [ ] Priority detection

### Unit Tests (Future)

```swift
// Example test structure
class MessageServiceTests: XCTestCase {
    var service: MessageService!
    
    override func setUp() {
        super.setUp()
        service = MessageService()
    }
    
    func testSendMessage() async throws {
        let message = Message(content: "Hello")
        let result = try await service.sendMessage(message)
        XCTAssertEqual(result.status, .sent)
    }
}
```

---

## Documentation

### Code Documentation

```swift
/// Brief description of the class/function
///
/// Detailed explanation of what this does and why.
///
/// - Parameters:
///   - param1: Description of first parameter
///   - param2: Description of second parameter
/// - Returns: Description of return value
/// - Throws: Description of possible errors
func exampleFunction(param1: String, param2: Int) throws -> Bool {
    // Implementation
}
```

### README Updates

If your changes affect:
- Installation process → Update `SETUP.md`
- Architecture → Update `ARCHITECTURE.md`
- Features → Update `README.md`
- API usage → Update relevant documentation

### Changelog

For significant changes, add entry to `CHANGELOG.md`:

```markdown
## [Unreleased]

### Added
- Voice message playback speed control (#123)

### Fixed
- Sign-in crash on iOS 17 (#456)

### Changed
- Updated Firebase SDK to 10.0 (#789)
```

---

## Feature Requests

### Proposing New Features

1. **Check existing issues**: Avoid duplicates
2. **Create detailed issue**:
   - Clear title
   - Problem description
   - Proposed solution
   - Alternative solutions considered
   - Additional context (screenshots, mockups)
3. **Wait for feedback**: Discuss with maintainers
4. **Get approval**: Before starting work

### Feature Proposal Template

```markdown
## Feature Request

**Problem**
Describe the problem this feature solves

**Proposed Solution**
Describe your proposed solution

**Alternatives Considered**
What other solutions did you consider?

**Additional Context**
Add mockups, screenshots, or examples

**Implementation Plan**
- [ ] Step 1
- [ ] Step 2
- [ ] Step 3
```

---

## Bug Reports

### Reporting Bugs

1. **Search existing issues**: Check if already reported
2. **Create detailed bug report**:
   - Clear title
   - Steps to reproduce
   - Expected behavior
   - Actual behavior
   - Screenshots/videos
   - Environment details

### Bug Report Template

```markdown
## Bug Report

**Description**
Clear description of the bug

**Steps to Reproduce**
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected Behavior**
What should happen

**Actual Behavior**
What actually happens

**Screenshots**
Add screenshots here

**Environment**
- iOS version: 17.0
- Device: iPhone 15 Pro
- App version: 1.0.0

**Additional Context**
Any other relevant information
```

---

## Community

### Communication Channels

- **GitHub Issues**: Bug reports, feature requests
- **GitHub Discussions**: General questions, ideas
- **Pull Requests**: Code contributions

### Getting Help

- Read the documentation first
- Search existing issues
- Ask in GitHub Discussions
- Be patient and respectful

---

## Recognition

Contributors will be recognized in:
- `CONTRIBUTORS.md` file
- Release notes
- Project README

---

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

## Questions?

If you have questions about contributing:
1. Check the [SETUP.md](SETUP.md) and [ARCHITECTURE.md](ARCHITECTURE.md)
2. Search existing issues
3. Create a new issue with the `question` label

---

## Thank You! 🎉

Every contribution, no matter how small, is valuable and appreciated!

---

**Last Updated**: October 24, 2025  
**Version**: 1.0.0

