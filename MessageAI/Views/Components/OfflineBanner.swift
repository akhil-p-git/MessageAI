//
//  OfflineBanner.swift
//  MessageAI
//
//  Displays offline/syncing status banner
//

import SwiftUI

struct OfflineBanner: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @ObservedObject var syncService = MessageSyncService.shared
    
    var body: some View {
        if !networkMonitor.isConnected || syncService.isSyncing {
            HStack(spacing: 8) {
                Image(systemName: networkMonitor.isConnected ? "arrow.triangle.2.circlepath" : "wifi.slash")
                    .foregroundColor(.white)
                
                Text(bannerText)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
                
                if syncService.isSyncing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                }
                
                if syncService.pendingMessageCount > 0 {
                    Text("(\(syncService.pendingMessageCount))")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(bannerColor)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    
    private var bannerText: String {
        if !networkMonitor.isConnected {
            return "Offline - Messages will sync when online"
        } else if syncService.isSyncing {
            return "Syncing messages..."
        }
        return ""
    }
    
    private var bannerColor: Color {
        if !networkMonitor.isConnected {
            return Color.orange
        } else if syncService.isSyncing {
            return Color.blue
        }
        return Color.gray
    }
}

struct MessageStatusIndicator: View {
    let status: MessageStatus
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: statusIcon)
                .font(.caption2)
                .foregroundColor(statusColor)
            
            if status == .pending {
                Text("Pending")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(statusColor)
            } else if status == .failed {
                Text("Failed")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(statusColor)
            }
        }
    }
    
    private var statusIcon: String {
        switch status {
        case .pending:
            return "clock"
        case .sending:
            return "arrow.up.circle"
        case .sent:
            return "checkmark"
        case .delivered:
            return "checkmark.circle"
        case .read:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.circle"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .pending:
            return .orange
        case .sending:
            return .blue
        case .sent:
            return .gray
        case .delivered:
            return .gray
        case .read:
            return .blue
        case .failed:
            return .red
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        OfflineBanner()
        
        HStack(spacing: 20) {
            MessageStatusIndicator(status: .pending)
            MessageStatusIndicator(status: .sending)
            MessageStatusIndicator(status: .sent)
            MessageStatusIndicator(status: .failed)
        }
    }
    .padding()
}

