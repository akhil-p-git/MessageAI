//
//  UserProfileView.swift
//  MessageAI
//
//  View-only profile for other users
//

import SwiftUI

struct UserProfileView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Picture") {
                    VStack(spacing: 16) {
                        ProfileImageView(
                            url: user.profilePictureURL,
                            size: 100,
                            fallbackText: user.displayName
                        )
                        
                        // Show status if available
                        if let status = user.status, !status.isEmpty {
                            Text(status)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                }
                
                Section("Profile Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display Name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(user.displayName)
                            .font(.body)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(user.email)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(user.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

#Preview {
    UserProfileView(
        user: User(
            id: "test",
            email: "test@example.com",
            displayName: "Test User",
            status: "Hello, I'm using MessageAI!"
        )
    )
}

