//
//  MainTabView.swift
//  MessageAI
//
//  Main tab view for authenticated users
//

import SwiftUI

struct MainTabView: View {
    
    // MARK: - Properties
    
    @State private var selectedTab = 0
    
    // MARK: - Body
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Conversations Tab
            ConversationsPlaceholderView()
                .tabItem {
                    Label("Conversations", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(0)
            
            // Profile Tab
            ProfilePlaceholderView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(1)
        }
        .tint(.firebaseOrange)
    }
}

// MARK: - Conversations Placeholder View

struct ConversationsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.firebaseOrange.opacity(0.2), Color.firebaseRed.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.firebaseOrange, Color.firebaseRed],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Title
                Text("Conversations")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                // Coming Soon Text
                Text("Coming soon!")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                // Description
                Text("Your conversations will appear here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Profile Placeholder View

struct ProfilePlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.firebaseOrange.opacity(0.2), Color.firebaseRed.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.firebaseOrange, Color.firebaseRed],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Title
                Text("Profile")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                // Coming Soon Text
                Text("Coming soon!")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                // Description
                Text("Your profile settings will appear here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
#endif

