//
//  ReadReceiptIndicator.swift
//  MessageAI
//
//  Visual indicator for message read receipts
//

import SwiftUI

struct ReadReceiptIndicator: View {
    let status: MessageStatus
    let readByCount: Int
    let isGroupChat: Bool
    let onTap: (() -> Void)?
    
    init(status: MessageStatus, readByCount: Int = 0, isGroupChat: Bool = false, onTap: (() -> Void)? = nil) {
        self.status = status
        self.readByCount = readByCount
        self.isGroupChat = isGroupChat
        self.onTap = onTap
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // Status icon
            Group {
                switch status {
                case .pending:
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    
                case .sending:
                    ProgressView()
                        .scaleEffect(0.6)
                    
                case .sent:
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                case .delivered:
                    HStack(spacing: -4) {
                        Image(systemName: "checkmark")
                        Image(systemName: "checkmark")
                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                    
                case .read:
                    HStack(spacing: -4) {
                        Image(systemName: "checkmark")
                        Image(systemName: "checkmark")
                    }
                    .font(.caption2)
                    .foregroundColor(.blue)
                    
                case .failed:
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            
            // Show read count for group chats
            if isGroupChat && status == .read && readByCount > 0 {
                Button {
                    onTap?()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "eye.fill")
                        Text("\(readByCount)")
                    }
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            Text("Sent:")
            ReadReceiptIndicator(status: .sent)
        }
        
        HStack {
            Text("Delivered:")
            ReadReceiptIndicator(status: .delivered)
        }
        
        HStack {
            Text("Read (1-on-1):")
            ReadReceiptIndicator(status: .read)
        }
        
        HStack {
            Text("Read (Group):")
            ReadReceiptIndicator(status: .read, readByCount: 3, isGroupChat: true) {
                print("Tapped read count")
            }
        }
        
        HStack {
            Text("Pending:")
            ReadReceiptIndicator(status: .pending)
        }
        
        HStack {
            Text("Failed:")
            ReadReceiptIndicator(status: .failed)
        }
    }
    .padding()
}

