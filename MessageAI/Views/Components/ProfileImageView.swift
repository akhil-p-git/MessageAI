import SwiftUI

struct ProfileImageView: View {
    let url: String?
    let size: CGFloat
    let fallbackText: String
    
    var body: some View {
        Group {
            if let urlString = url, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: size, height: size)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure(_):
                        fallbackView
                    @unknown default:
                        fallbackView
                    }
                }
            } else {
                fallbackView
            }
        }
    }
    
    private var fallbackView: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Text(fallbackText.prefix(1).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
            )
    }
}

#Preview {
    VStack(spacing: 20) {
        ProfileImageView(url: nil, size: 70, fallbackText: "John Doe")
        ProfileImageView(url: "https://example.com/image.jpg", size: 50, fallbackText: "Jane")
    }
}
