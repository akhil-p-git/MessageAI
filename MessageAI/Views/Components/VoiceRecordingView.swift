import SwiftUI

struct VoiceRecordingView: View {
    @StateObject private var recorder = AudioRecorderService()
    let onSend: (URL) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: {
                recorder.cancelRecording()
                onCancel()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.red)
            }
            
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                
                Text(formatTime(recorder.recordingTime))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            Button(action: {
                if let url = recorder.stopRecording() {
                    onSend(url)
                }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .onAppear {
            recorder.startRecording()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
