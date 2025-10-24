//
//  RootView.swift
//  MessageAI
//
//  Root view that handles authentication routing
//

import SwiftUI

struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Group {
            if authViewModel.isLoading {
                ProgressView()
            } else if authViewModel.isAuthenticated {
                MainTabView()
                    .environmentObject(authViewModel)
            } else {
                LoginView()
                    .environmentObject(authViewModel)
            }
        }
        .onAppear {
            print("📱 RootView appeared with theme: \(themeManager.selectedTheme.rawValue)")
            Task {
                await authViewModel.checkAuthState()
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environmentObject(ThemeManager())
    }
}
#endif
