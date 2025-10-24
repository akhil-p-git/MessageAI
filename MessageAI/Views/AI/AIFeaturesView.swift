//
//  AIFeaturesView.swift
//  MessageAI
//
//  Unified AI features panel with tabbed interface
//

import SwiftUI

struct AIFeaturesView: View {
    let conversationID: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: AITab = .summary
    
    enum AITab: String, CaseIterable {
        case summary = "Summary"
        case actionItems = "Tasks"
        case search = "Search"
        case decisions = "Decisions"
        
        var icon: String {
            switch self {
            case .summary: return "text.alignleft"
            case .actionItems: return "checkmark.circle"
            case .search: return "magnifyingglass"
            case .decisions: return "checkmark.seal"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Tab Bar
                tabBar
                
                Divider()
                
                // Content
                TabView(selection: $selectedTab) {
                    ForEach(AITab.allCases, id: \.self) { tab in
                        tabContent(for: tab)
                            .tag(tab)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("AI Features")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
        }
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AITab.allCases, id: \.self) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    private func tabButton(for tab: AITab) -> some View {
        Button {
            withAnimation(.spring()) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.callout)
                
                Text(tab.rawValue)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(selectedTab == tab ? Color.blue : Color(.systemGray6))
            )
            .foregroundColor(selectedTab == tab ? .white : .primary)
        }
    }
    
    // MARK: - Tab Content
    
    @ViewBuilder
    private func tabContent(for tab: AITab) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                switch tab {
                case .summary:
                    AISummaryCard(conversationID: conversationID)
                        .padding(.top)
                    
                case .actionItems:
                    ActionItemsView(conversationID: conversationID)
                        .padding(.top)
                    
                case .search:
                    SmartSearchView(conversationID: conversationID)
                        .padding(.top)
                    
                case .decisions:
                    DecisionsContainerView(conversationID: conversationID)
                        .padding(.top)
                }
            }
        }
    }
}

// MARK: - Decisions Container View

struct DecisionsContainerView: View {
    let conversationID: String
    @StateObject private var viewModel = DecisionsViewModel()
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.title3)
                
                Text("Decision Tracking")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)
            
            // Content
            if viewModel.isLoading {
                DecisionsLoadingView()
                    .padding(.horizontal)
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
            } else {
                DecisionsView(decisions: viewModel.decisions)
                    .padding(.horizontal)
            }
            
            // Refresh Button
            Button {
                Task {
                    await viewModel.fetchDecisions(conversationID: conversationID)
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Decisions")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
        }
        .task {
            if viewModel.decisions.isEmpty && !viewModel.isLoading {
                await viewModel.fetchDecisions(conversationID: conversationID)
            }
        }
    }
}

// MARK: - Decisions ViewModel

@MainActor
class DecisionsViewModel: ObservableObject {
    @Published var decisions: [Decision] = []
    @Published var isLoading = false
    @Published var error: String?
    
    func fetchDecisions(conversationID: String) async {
        isLoading = true
        error = nil
        
        do {
            let result = try await AIService.shared.trackDecisions(
                conversationID: conversationID
            )
            decisions = result.decisions
        } catch {
            self.error = "Failed to load decisions: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

// MARK: - Preview

#Preview("AI Features View") {
    AIFeaturesView(conversationID: "test-conversation-id")
}

