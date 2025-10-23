import SwiftUI

struct TypingIndicatorView: View {
    @State private var dotScale1: CGFloat = 0.5
    @State private var dotScale2: CGFloat = 0.5
    @State private var dotScale3: CGFloat = 0.5
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.gray)
                .frame(width: 8, height: 8)
                .scaleEffect(dotScale1)
            
            Circle()
                .fill(Color.gray)
                .frame(width: 8, height: 8)
                .scaleEffect(dotScale2)
            
            Circle()
                .fill(Color.gray)
                .frame(width: 8, height: 8)
                .scaleEffect(dotScale3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
        .cornerRadius(18)
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        withAnimation(Animation.easeInOut(duration: 0.6).repeatForever()) {
            dotScale1 = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(Animation.easeInOut(duration: 0.6).repeatForever()) {
                dotScale2 = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(Animation.easeInOut(duration: 0.6).repeatForever()) {
                dotScale3 = 1.0
            }
        }
    }
}

#Preview {
    TypingIndicatorView()
}
