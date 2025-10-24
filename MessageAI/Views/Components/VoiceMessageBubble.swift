import SwiftUI

struct VoiceMessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    @StateObject private var player = AudioPlayerService()
    @State private var isLoading = false
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            HStack(spacing: 12) {
                Button(action: {
                    playAudio()
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(isCurrentUser ? .white : .blue)
                }
                .disabled(isLoading)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 2) {
                        ForEach(0..<20, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isCurrentUser ? Color.white.opacity(0.7) : Color.blue.opacity(0.7))
                                .frame(width: 3, height: CGFloat(12 + (index % 3) * 4))
                        }
                    }
                    .frame(height: 24)
                    
                    Text(formatDuration())
                        .font(.caption)
                        .foregroundColor(isCurrentUser ? .white.opacity(0.8) : .secondary)
                }
                
                if isLoading {
                    ProgressView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isCurrentUser ? Color.blue : Color(.systemGray5))
            .cornerRadius(18)
            
            if !isCurrentUser { Spacer() }
        }
    }
    
    private var isPlaying: Bool {
        player.isPlaying && player.playingMessageID == message.id
    }
    
    private func playAudio() {
        guard let urlString = message.mediaURL, let url = URL(string: urlString) else {
            print("❌ No audio URL")
            return
        }
        
        if url.scheme == "https" || url.scheme == "http" {
            downloadAndPlay(url: url)
        } else {
            player.playAudio(url: url, messageID: message.id)
        }
    }
    
    private func downloadAndPlay(url: URL) {
        isLoading = true
        
        URLSession.shared.downloadTask(with: url) { localURL, response, error in
            guard let localURL = localURL, error == nil else {
                print("❌ Download error: \(error?.localizedDescription ?? "Unknown")")
                Task { @MainActor in
                    isLoading = false
                }
                return
            }
            
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.moveItem(at: localURL, to: tempURL)
            
            Task { @MainActor in
                isLoading = false
                player.playAudio(url: tempURL, messageID: message.id)
            }
        }.resume()
    }
    
    private func formatDuration() -> String {
        let time: TimeInterval
        
        if player.playingMessageID == message.id && player.isPlaying {
            // Show current playback time
            time = player.currentTime
        } else if player.playingMessageID == message.id && player.duration > 0 {
            // Show total duration if we've loaded this message
            time = player.duration
        } else {
            // Default to showing "Voice message" since we don't have duration stored
            return "Voice message"
        }
        
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
