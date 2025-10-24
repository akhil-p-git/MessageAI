//
//  PriorityDetectionView.swift
//  MessageAI
//
//  Priority Detection AI Feature
//

import SwiftUI

struct PriorityDetectionView: View {
    let conversationID: String
    
    @State private var messageText = ""
    @State private var isAnalyzing = false
    @State private var priorityResult: PriorityResult?
    @State private var errorMessage: String?
    @State private var showingResult = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Priority Detection")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("AI analyzes messages to detect urgency and priority level")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // Input Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Message to Analyze")
                            .font(.headline)
                        
                        TextEditor(text: $messageText)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        
                        Text("Enter a message to check its priority level")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Analyze Button
                    Button(action: analyzePriority) {
                        HStack {
                            if isAnalyzing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                                Text("Analyze Priority")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(messageText.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(messageText.isEmpty || isAnalyzing)
                    .padding(.horizontal)
                    
                    // Error Message
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.subheadline)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    // Result Section
                    if let result = priorityResult {
                        resultView(result: result)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func resultView(result: PriorityResult) -> some View {
        VStack(spacing: 20) {
            // Priority Badge
            VStack(spacing: 12) {
                Image(systemName: result.priorityIcon)
                    .font(.system(size: 50))
                    .foregroundColor(result.priorityColor)
                
                Text(result.priority.uppercased())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(result.priorityColor)
                
                Text("Priority Level")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(result.priorityColor.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Urgency Score
            VStack(spacing: 8) {
                Text("Urgency Score")
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Text(String(format: "%.0f", result.urgencyScore))
                        .font(.system(size: 40, weight: .bold))
                    Text("/ 100")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                        
                        Rectangle()
                            .fill(result.priorityColor)
                            .frame(width: geometry.size.width * (result.urgencyScore / 100), height: 8)
                    }
                    .cornerRadius(4)
                }
                .frame(height: 8)
            }
            .padding(.horizontal)
            
            // Reason
            if let reason = result.reason {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Analysis")
                        .font(.headline)
                    
                    Text(reason)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Urgency Indicators
            if !result.urgencyIndicators.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Urgency Indicators")
                        .font(.headline)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(result.urgencyIndicators, id: \.self) { indicator in
                            Text(indicator)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(result.priorityColor.opacity(0.2))
                                .foregroundColor(result.priorityColor)
                                .cornerRadius(16)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }
    
    private func analyzePriority() {
        errorMessage = nil
        priorityResult = nil
        isAnalyzing = true
        
        Task {
            do {
                let result = try await AIService.shared.detectPriority(
                    messageText: messageText,
                    conversationContext: nil
                )
                
                await MainActor.run {
                    withAnimation(.spring()) {
                        self.priorityResult = result
                        self.isAnalyzing = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isAnalyzing = false
                }
            }
        }
    }
}

// Simple FlowLayout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: ProposedViewSize(result.frames[index].size))
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

#Preview {
    PriorityDetectionView(conversationID: "test-123")
}

