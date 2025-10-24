//
//  DecisionsView.swift
//  MessageAI
//
//  UI component for displaying tracked decisions from conversations
//

import SwiftUI

struct DecisionsView: View {
    let decisions: [Decision]
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
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
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Key Decisions")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("\(decisions.count) decision\(decisions.count == 1 ? "" : "s") tracked")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Content
            if isExpanded {
                if decisions.isEmpty {
                    EmptyDecisionsView()
                } else {
                    Divider()
                    
                    VStack(spacing: 12) {
                        ForEach(decisions) { decision in
                            DecisionCard(decision: decision)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.green.opacity(0.3), .mint.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .green.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Decision Card

struct DecisionCard: View {
    let decision: Decision
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Topic Badge
            HStack {
                Text(decision.topic)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.2))
                    )
                
                Spacer()
                
                ConfidenceBadge(confidence: decision.confidence)
            }
            
            // Decision
            Text(decision.decision)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            // Participants
            if !decision.participants.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(decision.participants.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Timestamp
            if let timestamp = decision.timestamp {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(timestamp)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }
}

// MARK: - Confidence Badge

struct ConfidenceBadge: View {
    let confidence: ConfidenceLevel
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(confidence.rawValue.capitalized)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(color.opacity(0.2))
        )
        .foregroundColor(color)
    }
    
    var color: Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .gray
        }
    }
    
    var icon: String {
        switch confidence {
        case .high: return "checkmark.circle.fill"
        case .medium: return "questionmark.circle.fill"
        case .low: return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - Empty State

struct EmptyDecisionsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No decisions tracked yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("I'll automatically detect when the team makes decisions")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Loading State

struct DecisionsLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
                
                Text("Tracking Decisions...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                ProgressView()
                    .tint(.green)
            }
            
            VStack(spacing: 12) {
                ForEach(0..<2) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 80, height: 20)
                            Spacer()
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 60, height: 20)
                        }
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 10)
                            .frame(maxWidth: 200)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                    )
                    .shimmer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.08))
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Timeline View (Alternative Layout)

struct DecisionsTimelineView: View {
    let decisions: [Decision]
    
    var sortedDecisions: [Decision] {
        decisions.sorted { decision1, decision2 in
            guard let time1 = decision1.timestamp, let time2 = decision2.timestamp else {
                return false
            }
            return time1 > time2
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(sortedDecisions.enumerated()), id: \.element.id) { index, decision in
                    HStack(alignment: .top, spacing: 12) {
                        // Timeline
                        VStack(spacing: 0) {
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.green.opacity(0.3))
                                    .frame(width: 2, height: 20)
                            }
                            
                            Circle()
                                .fill(Color.green)
                                .frame(width: 12, height: 12)
                            
                            if index < sortedDecisions.count - 1 {
                                Rectangle()
                                    .fill(Color.green.opacity(0.3))
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        .frame(width: 12)
                        
                        // Content
                        DecisionTimelineCard(decision: decision)
                            .padding(.bottom, 20)
                    }
                }
            }
            .padding()
        }
    }
}

struct DecisionTimelineCard: View {
    let decision: Decision
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Timestamp
            if let timestamp = decision.timestamp {
                Text(timestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Decision
            Text(decision.decision)
                .font(.subheadline)
                .fontWeight(.medium)
            
            // Topic
            Text(decision.topic)
                .font(.caption)
                .foregroundColor(.green)
            
            // Participants
            if !decision.participants.isEmpty {
                Text("Involved: \(decision.participants.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Preview

#Preview("Decisions View") {
    VStack(spacing: 20) {
        DecisionsView(decisions: [
            Decision(from: [
                "decision": "Launch new feature on March 15th",
                "topic": "Product Launch",
                "participantsInvolved": ["Sarah", "Mike", "John"],
                "timestamp": "2024-03-10T14:30:00Z",
                "confidence": "high"
            ])!,
            Decision(from: [
                "decision": "Use Firebase for backend infrastructure",
                "topic": "Technical Architecture",
                "participantsInvolved": ["Mike", "David"],
                "timestamp": "2024-03-09T10:15:00Z",
                "confidence": "high"
            ])!,
            Decision(from: [
                "decision": "Tentatively agreed to $99/month pricing",
                "topic": "Pricing Strategy",
                "participantsInvolved": ["Sarah", "Emily"],
                "confidence": "medium"
            ])!
        ])
        
        DecisionsLoadingView()
    }
    .padding()
}

#Preview("Timeline View") {
    DecisionsTimelineView(decisions: [
        Decision(from: [
            "decision": "Launch new feature on March 15th",
            "topic": "Product Launch",
            "participantsInvolved": ["Sarah", "Mike"],
            "timestamp": "Today at 2:30 PM",
            "confidence": "high"
        ])!,
        Decision(from: [
            "decision": "Use Firebase for backend",
            "topic": "Architecture",
            "participantsInvolved": ["Mike"],
            "timestamp": "Yesterday at 10:15 AM",
            "confidence": "high"
        ])!
    ])
    .frame(height: 400)
}
