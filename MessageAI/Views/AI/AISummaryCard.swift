//
//  AISummaryCard.swift
//  MessageAI
//
//  AI-powered conversation summary card
//

import SwiftUI

struct AISummaryCard: View {
    @StateObject private var viewModel = SummaryViewModel()
    let conversationID: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .font(.title3)
                    
                    Text("AI Summary")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Content
            if isExpanded {
                if viewModel.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Analyzing conversation...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .shimmer()
                } else if let error = viewModel.error {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else if let summary = viewModel.summary {
                    VStack(alignment: .leading, spacing: 16) {
                        // Main summary points
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(summary.points.enumerated()), id: \.offset) { index, point in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 20, alignment: .leading)
                                    
                                    Text(point)
                                        .font(.callout)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Metadata
                        HStack {
                            Label("\(summary.messageCount) messages", systemImage: "message")
                            Spacer()
                            Label(formatDate(summary.timestamp), systemImage: "clock")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        // Refresh button
                        Button {
                            Task {
                                await viewModel.fetchSummary(conversationID: conversationID)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh Summary")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
        .task {
            if viewModel.summary == nil {
                await viewModel.fetchSummary(conversationID: conversationID)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - ViewModel

@MainActor
class SummaryViewModel: ObservableObject {
    @Published var summary: ConversationSummary?
    @Published var isLoading = false
    @Published var error: String?
    
    func fetchSummary(conversationID: String) async {
        isLoading = true
        error = nil
        
        do {
            summary = try await AIService.shared.summarizeThread(
                conversationID: conversationID
            )
        } catch {
            self.error = "Failed to generate summary"
        }
        
        isLoading = false
    }
}

// MARK: - Preview

#Preview("AI Summary Card") {
    AISummaryCard(conversationID: "test-conversation")
        .padding()
}
