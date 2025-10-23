import SwiftUI

struct LastSeenView: View {
    let isOnline: Bool
    let lastSeen: Date?
    
    var body: some View {
        if isOnline {
            Text("Online")
                .font(.caption)
                .foregroundColor(.green)
        } else if let lastSeen = lastSeen {
            Text("Last seen \(formatLastSeen(lastSeen))")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            Text("Offline")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func formatLastSeen(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        LastSeenView(isOnline: true, lastSeen: nil)
        LastSeenView(isOnline: false, lastSeen: Date().addingTimeInterval(-300))
        LastSeenView(isOnline: false, lastSeen: Date().addingTimeInterval(-3600))
        LastSeenView(isOnline: false, lastSeen: Date().addingTimeInterval(-86400))
    }
}
