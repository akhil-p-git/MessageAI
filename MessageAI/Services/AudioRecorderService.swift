import Foundation
import AVFoundation
import Combine

@MainActor
class AudioRecorderService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var recordingURL: URL?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Initial setup - will be reconfigured when recording starts
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            print("✅ Audio session initialized")
        } catch {
            print("❌ Error setting up audio session: \(error)")
        }
    }
    
    func startRecording() {
        print("\n🎤 AudioRecorderService: Starting recording...")
        
        // Check permission status first
        let permissionStatus = AVAudioSession.sharedInstance().recordPermission
        
        switch permissionStatus {
        case .granted:
            print("✅ Microphone permission already granted")
            self.beginRecording()
            
        case .denied:
            print("❌ Microphone permission denied!")
            return
            
        case .undetermined:
            print("⏳ Requesting microphone permission...")
            // Request permission asynchronously to avoid blocking
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if granted {
                        print("✅ Microphone permission granted")
                        self.beginRecording()
                    } else {
                        print("❌ Microphone permission denied!")
                    }
                }
            }
            
        @unknown default:
            print("⚠️ Unknown permission status")
            return
        }
    }
    
    private func beginRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("\(UUID().uuidString).m4a")
        
        print("   Recording to: \(audioFilename.path)")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            // Use simple configuration - already set up in init()
            let audioSession = AVAudioSession.sharedInstance()
            
            // Reactivate if needed (lightweight operation)
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true)
            }
            
            print("   Audio session ready")
            print("      Input available: \(audioSession.isInputAvailable)")
            
            self.audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            self.audioRecorder?.delegate = self
            self.audioRecorder?.isMeteringEnabled = true
            self.audioRecorder?.prepareToRecord()
            
            let success = self.audioRecorder?.record() ?? false
            
            if success {
                self.recordingURL = audioFilename
                self.isRecording = true
                self.recordingTime = 0
                
                self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    Task { @MainActor in
                        self.recordingTime += 0.1
                        
                        // Check if recording is actually happening
                        if let recorder = self.audioRecorder, recorder.isRecording {
                            recorder.updateMeters()
                            let avgPower = recorder.averagePower(forChannel: 0)
                            if Int(self.recordingTime * 10) % 10 == 0 {
                                print("   🎙️ Recording... \(String(format: "%.1f", self.recordingTime))s (level: \(avgPower) dB)")
                            }
                        }
                    }
                }
                
                print("✅ Recording started successfully!")
                print("   Recorder is recording: \(self.audioRecorder?.isRecording ?? false)")
            } else {
                print("❌ Failed to start recording (record() returned false)")
            }
        } catch {
            print("❌ Error starting recording: \(error)")
            print("   Error details: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   Error code: \(nsError.code)")
                print("   Error domain: \(nsError.domain)")
            }
        }
    }
    
    func stopRecording() -> URL? {
        print("\n🛑 AudioRecorderService: Stopping recording...")
        
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        
        if let url = recordingURL {
            // Check if file exists and has content
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    let fileSize = attributes[.size] as? Int ?? 0
                    print("✅ Recording stopped successfully!")
                    print("   File: \(url.lastPathComponent)")
                    print("   Size: \(fileSize) bytes")
                    print("   Duration: \(String(format: "%.1f", recordingTime))s")
                    
                    if fileSize == 0 {
                        print("⚠️ WARNING: Recording file is empty!")
                    }
                } catch {
                    print("⚠️ Could not read file attributes: \(error)")
                }
            } else {
                print("❌ Recording file does not exist at path: \(url.path)")
            }
        } else {
            print("❌ No recording URL available")
        }
        
        return recordingURL
    }
    
    func cancelRecording() {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        recordingURL = nil
        recordingTime = 0
    }
}

extension AudioRecorderService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("❌ Recording failed")
        }
    }
}
