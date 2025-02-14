import Cocoa
import AVFoundation
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate, AVAudioRecorderDelegate {
    var viewModel = TranscriptionViewModel()
    var isRecording = false
    var audioRecorder: AVAudioRecorder?
    var recordedFileURL: URL?
    var meterTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // If you’re switching to the CGEventTap approach, remove your Carbon hotkey code.
        // Otherwise, start your hotkey handler as before.
        // For example, if using CGEventTap:
        let keyTapHandler = KeyTapHandler()
        keyTapHandler.startListening(with: self)
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording-\(UUID().uuidString).m4a"
        recordedFileURL = tempDir.appendingPathComponent(fileName)
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordedFileURL!, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true
            DispatchQueue.main.async {
                self.viewModel.appendTranscript("\nRecording started...")
                self.viewModel.isRecording = true
            }
            
            // Start a timer to update audio level from recorder meters
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true, block: { [weak self] timer in
                guard let self = self,
                      let recorder = self.audioRecorder,
                      recorder.isRecording else {
                    timer.invalidate()
                    return
                }
                recorder.updateMeters()
                // averagePower(forChannel:) returns dB (negative values); normalize to 0...1.
                let power = recorder.averagePower(forChannel: 0)
                // Example normalization: shift so that -50dB becomes 0 and 0dB becomes 1 (clamp as needed)
                let level = max(0, min(1, (power + 50) / 50))
                DispatchQueue.main.async {
                    self.viewModel.audioLevel = level
                    print("Audio level: \(level)")  // Debug: Print current level
                }
            })
        } catch {
            DispatchQueue.main.async {
                self.viewModel.appendTranscript("\nFailed to start recording: \(error)")
            }
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        meterTimer?.invalidate()
        meterTimer = nil
        isRecording = false
        DispatchQueue.main.async {
            self.viewModel.appendTranscript("\nRecording stopped. Transcribing...")
            self.viewModel.isRecording = false
        }
        transcribeAudio(fileURL: recordedFileURL!)
    }
    
    func transcribeAudio(fileURL: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/whisper")
            let outputDir = fileURL.deletingLastPathComponent().path
            process.arguments = [
                        fileURL.path,
                        "--model", "tiny.en",
                        "--output_format", "txt",
                        "--output_dir", outputDir
                    ]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
            } catch {
                DispatchQueue.main.async {
                    self.viewModel.appendTranscript("\nError running transcription: \(error)")
                }
                return
            }
            
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "No transcription output."
            
            DispatchQueue.main.async {
                self.viewModel.appendTranscript("\nTranscription:\n\(output)")
            }
        }
    }
}
