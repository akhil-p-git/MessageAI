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
        print("   URL: \(url.path)")
        print("   Message ID: \(messageID.prefix(8))...")
        
        if playingMessageID == messageID && isPlaying {
            pauseAudio()
            return
        }
        
        stopAudio()
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ File does not exist at path: \(url.path)")
            return
        }
        
        // Check file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int ?? 0
            print("   📁 File exists")
            print("   File size: \(fileSize) bytes")
            
            if fileSize == 0 {
                print("❌ File is empty (0 bytes)")
                return
            }
        } catch {
            print("❌ Cannot read file attributes: \(error.localizedDescription)")
            return
        }
        
        do {
            // Configure audio session for playback
            let audioSession = AVAudioSession.sharedInstance()
            
            // First, try to deactivate any existing session
            try? audioSession.setActive(false)
            
            // Set category for playback - use .playAndRecord to match recording format
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            print("   ✅ Audio session configured for playback")
            print("      Category: \(audioSession.category.rawValue)")
            print("      Available: \(audioSession.isOtherAudioPlaying ? "Other audio playing" : "Ready")")
            
            // Try to create the audio player
            print("   🎵 Creating audio player...")
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            
            guard let player = audioPlayer else {
                print("❌ Failed to create audio player")
                return
            }
            
            // Prepare to play
            let prepared = player.prepareToPlay()
            print("   Prepare to play: \(prepared ? "Success" : "Failed")")
            
            duration = player.duration
            playingMessageID = messageID
            
            print("   ✅ Audio player initialized")
            print("   Duration: \(duration)s")
            print("   Format: \(player.format)")
            print("   Channels: \(player.numberOfChannels)")
            
            // Start playback
            let playSuccess = player.play()
            if playSuccess {
                isPlaying = true
                print("   ✅ Playback started!")
                print("   Volume: \(player.volume)")
                print("   Is playing: \(player.isPlaying)")
                
                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    Task { @MainActor in
                        self.currentTime = self.audioPlayer?.currentTime ?? 0
                    }
                }
            } else {
                print("   ❌ Playback failed to start")
                print("   Player state: isPlaying=\(player.isPlaying)")
            }
        } catch let error as NSError {
            print("❌ Error playing audio!")
            print("   Error: \(error.localizedDescription)")
            print("   Domain: \(error.domain)")
            print("   Code: \(error.code)")
            print("   User Info: \(error.userInfo)")
            
            // Decode common audio errors
            switch error.code {
            case -11020, 2003334207:
                print("   → Invalid or unsupported audio file format")
            case -50:
                print("   → Invalid parameter")
            case -43:
                print("   → File not found")
            default:
                print("   → Unknown audio error")
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
