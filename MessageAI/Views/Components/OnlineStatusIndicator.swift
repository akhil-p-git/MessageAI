import SwiftUI

struct OnlineStatusIndicator: View {
    let isOnline: Bool
    let size: CGFloat
    
    init(isOnline: Bool, size: CGFloat = 12) {
        self.isOnline = isOnline
        self.size = size
    }
    
    var body: some View {
        Circle()
            .fill(isOnline ? Color.green : Color.gray)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
    }
}

#Preview {
    HStack(spacing: 20) {
        OnlineStatusIndicator(isOnline: true)
        OnlineStatusIndicator(isOnline: false)
    }
}
