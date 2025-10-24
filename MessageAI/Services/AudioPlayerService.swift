import Foundation
import AVFoundation
import Combine

@MainActor
class AudioPlayerService: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playingMessageID: String?
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    func playAudio(url: URL, messageID: String) {
        print("\n🔊 AudioPlayerService: Attempting to play audio...")
        print("   URL: \(url)")
        print("   Message ID: \(messageID.prefix(8))...")
        
        if playingMessageID == messageID && isPlaying {
            pauseAudio()
            return
        }
        
        stopAudio()
        
        do {
            // CRITICAL: Use .playAndRecord so we can play recorded audio
            // .playback mode doesn't work with recordings made in .playAndRecord mode
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            print("   ✅ Audio session configured for playback")
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            duration = audioPlayer?.duration ?? 0
            playingMessageID = messageID
            
            print("   ✅ Audio player initialized")
            print("   Duration: \(duration)s")
            
            let playSuccess = audioPlayer?.play() ?? false
            if playSuccess {
                isPlaying = true
                print("   ✅ Playback started!")
                
                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    Task { @MainActor in
                        self.currentTime = self.audioPlayer?.currentTime ?? 0
                    }
                }
            } else {
                print("   ❌ Playback failed to start")
            }
        } catch {
            print("❌ Error playing audio: \(error)")
            print("   Error details: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   Error code: \(nsError.code)")
                print("   Error domain: \(nsError.domain)")
            }
        }
    }
    
    func pauseAudio() {
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
    }
    
    func stopAudio() {
        audioPlayer?.stop()
        timer?.invalidate()
        isPlaying = false
        currentTime = 0
        playingMessageID = nil
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
}

extension AudioPlayerService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stopAudio()
        }
    }
}
