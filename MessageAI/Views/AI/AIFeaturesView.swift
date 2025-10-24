//
//  AIFeaturesView.swift
//  MessageAI
//
//  Unified AI features panel with tabbed interface
//

import SwiftUI
import Combine

struct AIFeaturesView: View {
    let conversationID: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: AITab = .summary
    @State private var showDebugPanel = false
    @State private var healthCheckStatus: HealthStatus = .unknown
    @State private var isRunningHealthCheck = false
    
    enum HealthStatus {
        case unknown, checking, healthy, unhealthy
        
        var icon: String {
            switch self {
            case .unknown: return "circle.dotted"
            case .checking: return "arrow.trianglehead.2.clockwise.rotate.90.circle"
            case .healthy: return "checkmark.circle.fill"
            case .unhealthy: return "xmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .unknown: return .gray
            case .checking: return .blue
            case .healthy: return .green
            case .unhealthy: return .red
            }
        }
        
        var text: String {
            switch self {
            case .unknown: return "Not checked"
            case .checking: return "Checking..."
            case .healthy: return "Connected"
            case .unhealthy: return "Connection failed"
            }
        }
    }
    
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
                    HStack(spacing: 12) {
                        // Health status indicator
                        Button {
                            showDebugPanel = true
                        } label: {
                            Image(systemName: healthCheckStatus.icon)
                                .foregroundColor(healthCheckStatus.color)
                        }
                        
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
            .sheet(isPresented: $showDebugPanel) {
                DebugPanelView(
                    healthCheckStatus: $healthCheckStatus,
                    isRunningHealthCheck: $isRunningHealthCheck,
                    conversationID: conversationID
                )
            }
            .task {
                // Auto-run health check on appear
                if healthCheckStatus == .unknown {
                    await runHealthCheck()
                }
            }
        }
    }
    
    // MARK: - Health Check
    
    private func runHealthCheck() async {
        healthCheckStatus = .checking
        isRunningHealthCheck = true
        
        let isHealthy = await AIService.shared.healthCheck()
        
        await MainActor.run {
            healthCheckStatus = isHealthy ? .healthy : .unhealthy
            isRunningHealthCheck = false
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

// MARK: - Debug Panel View

struct DebugPanelView: View {
    @Binding var healthCheckStatus: AIFeaturesView.HealthStatus
    @Binding var isRunningHealthCheck: Bool
    let conversationID: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isGeneratingTestData = false
    @State private var testDataMessage = ""
    @State private var showTestDataAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // Health Status Section
                Section {
                    HStack {
                        Image(systemName: healthCheckStatus.icon)
                            .foregroundColor(healthCheckStatus.color)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Firebase Connection")
                                .font(.headline)
                            Text(healthCheckStatus.text)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if isRunningHealthCheck {
                            ProgressView()
                        }
                    }
                    .padding(.vertical, 8)
                    
                    Button {
                        Task {
                            await runHealthCheck()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Run Health Check")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isRunningHealthCheck)
                } header: {
                    Text("Connection Status")
                } footer: {
                    Text("Verifies that Firebase Cloud Functions are accessible and responding.")
                }
                
                // Test Data Section
                Section {
                    HStack {
                        Image(systemName: "testtube.2")
                            .foregroundColor(.blue)
                        Text("Current Conversation ID")
                        Spacer()
                    }
                    
                    Text(conversationID)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                    
                    Button {
                        Task {
                            await generateTestData()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Generate Test Conversation")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isGeneratingTestData)
                    
                    if isGeneratingTestData {
                        HStack {
                            ProgressView()
                            Text("Generating test data...")
                                .font(.caption)
                        }
                    }
                    
                    if !testDataMessage.isEmpty {
                        Text(testDataMessage)
                            .font(.caption)
                            .foregroundColor(testDataMessage.contains("✅") ? .green : .red)
                    }
                } header: {
                    Text("Test Data")
                } footer: {
                    Text("Creates a test conversation with sample messages containing decisions, action items, and deadlines for testing AI features.")
                }
                
                // Debug Info Section
                Section {
                    HStack {
                        Text("Debug Logging")
                        Spacer()
                        Text("Enabled")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("AI Service Version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Debug Information")
                } footer: {
                    Text("Check Xcode console for detailed logs of all AI service calls.")
                }
                
                // Instructions Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        InstructionRow(
                            icon: "1.circle.fill",
                            title: "Generate Test Data",
                            description: "Create a conversation with sample messages"
                        )
                        
                        InstructionRow(
                            icon: "2.circle.fill",
                            title: "Open Test Conversation",
                            description: "Navigate to the generated conversation"
                        )
                        
                        InstructionRow(
                            icon: "3.circle.fill",
                            title: "Try AI Features",
                            description: "Tap sparkles icon and test each feature"
                        )
                        
                        InstructionRow(
                            icon: "4.circle.fill",
                            title: "Check Console",
                            description: "View detailed logs in Xcode console"
                        )
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Testing Instructions")
                }
            }
            .navigationTitle("Debug Panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func runHealthCheck() async {
        healthCheckStatus = .checking
        isRunningHealthCheck = true
        
        let isHealthy = await AIService.shared.healthCheck()
        
        await MainActor.run {
            healthCheckStatus = isHealthy ? .healthy : .unhealthy
            isRunningHealthCheck = false
        }
    }
    
    private func generateTestData() async {
        guard let currentUser = authViewModel.currentUser else {
            testDataMessage = "❌ No user logged in"
            return
        }
        
        isGeneratingTestData = true
        testDataMessage = "Generating test data..."
        
        do {
            let newConversationID = try await TestDataGenerator.shared.generateTestConversation(currentUserID: currentUser.id)
            testDataMessage = "✅ Test conversation created!\nID: \(newConversationID)"
            showTestDataAlert = true
        } catch {
            testDataMessage = "❌ Failed: \(error.localizedDescription)"
        }
        
        isGeneratingTestData = false
    }
}

struct InstructionRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview("AI Features View") {
    AIFeaturesView(conversationID: "test-conversation-id")
        .environmentObject(AuthViewModel())
}

