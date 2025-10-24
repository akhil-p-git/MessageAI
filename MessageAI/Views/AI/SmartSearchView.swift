//
//  SmartSearchView.swift
//  MessageAI
//
//  AI-powered semantic search across conversations
//

import SwiftUI
import Combine
import FirebaseFunctions

struct SmartSearchView: View {
    @StateObject private var viewModel = SmartSearchViewModel()
    let conversationID: String
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Ask anything...", text: $viewModel.query)
                    .focused($isSearchFocused)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .onSubmit {
                        Task {
                            await viewModel.search(conversationID: conversationID)
                        }
                    }
                
                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.query = ""
                        viewModel.results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .padding()
            
            Divider()
            
            // Results
            ScrollView {
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Searching...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
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
                    .padding(.vertical, 48)
                } else if viewModel.results.isEmpty && !viewModel.query.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No results found")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else if viewModel.query.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.system(size: 60))
                            .foregroundColor(.blue.opacity(0.5))
                        
                        Text("Smart Search")
                            .font(.title2.bold())
                        
                        Text("Ask natural questions like:\n• \"What did Sarah say about the budget?\"\n• \"When is the deadline?\"\n• \"Show me all decisions\"")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                    .padding(.horizontal, 32)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.results) { result in
                            SearchResultCard(result: result)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }
}

struct SearchResultCard: View {
    let result: SearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Message content
            Text(result.message)
                .font(.body)
                .foregroundColor(.primary)
            
            Divider()
            
            // Metadata
            HStack {
                if let sender = result.sender {
                    Label(sender, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Label(formatDate(result.timestamp), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Relevance score
            if result.relevanceScore > 0.8 {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Highly Relevant")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - ViewModel
@MainActor
class SmartSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [SearchResult] = []
    @Published var isLoading = false
    @Published var error: String?
    
    func search(conversationID: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let searchResults = try await AIService.shared.smartSearch(
                conversationID: conversationID,
                query: query
            )
            results = searchResults.results
        } catch {
            self.error = "Search failed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
