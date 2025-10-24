//
//  ActionItemsView.swift
//  MessageAI
//
//  AI-powered action item extraction and tracking
//

import SwiftUI
import Combine
import FirebaseFunctions

struct ActionItemsView: View {
    @StateObject private var viewModel = ActionItemsViewModel()
    let conversationID: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.title3)
                
                Text("Action Items")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(viewModel.items.count) task\(viewModel.items.count == 1 ? "" : "s") identified")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Content
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Analyzing conversation...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else if let error = viewModel.error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else if viewModel.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("No action items found")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(viewModel.items) { item in
                            ActionItemRow(item: item)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Refresh Button
            Button {
                Task {
                    await viewModel.fetchActionItems(conversationID: conversationID)
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .task {
            await viewModel.fetchActionItems(conversationID: conversationID)
        }
    }
}

struct ActionItemRow: View {
    let item: ActionItem
    @State private var isChecked = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                isChecked.toggle()
            } label: {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isChecked ? .green : .gray)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.task)
                    .font(.body)
                    .foregroundColor(isChecked ? .secondary : .primary)
                    .strikethrough(isChecked)
                
                if let assignee = item.assignee {
                    Label(assignee, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                if let deadline = item.deadline {
                    Label(formatDate(deadline), systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if let priority = item.priority, priority != "normal" {
                    Text(priority.uppercased())
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(priorityColor(priority))
                        )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high", "urgent":
            return .red
        case "medium":
            return .orange
        default:
            return .blue
        }
    }
}

// MARK: - ViewModel
@MainActor
class ActionItemsViewModel: ObservableObject {
    @Published var items: [ActionItem] = []
    @Published var isLoading = false
    @Published var error: String?
    
    func fetchActionItems(conversationID: String) async {
        isLoading = true
        error = nil
        
        do {
            let result = try await AIService.shared.extractActionItems(
                conversationID: conversationID
            )
            items = result.items
        } catch {
            self.error = "Failed to load action items: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
