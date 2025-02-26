import Cocoa
import AVFoundation
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate, AVAudioRecorderDelegate {
    var viewModel = TranscriptionViewModel()
    var isRecording = false
    var audioRecorder: AVAudioRecorder?
    var recordedFileURL: URL?
    var meterTimer: Timer?
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        viewModel.appDelegate = self
        setupStatusBarItem()
        
        // If you're switching to the CGEventTap approach, remove your Carbon hotkey code.
        // Otherwise, start your hotkey handler as before.
        // For example, if using CGEventTap:
        let keyTapHandler = KeyTapHandler()
        keyTapHandler.startListening(with: self)
    }
    
    func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Microwhisper")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Start Recording", action: #selector(menuStartRecording), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Stop Recording", action: #selector(menuStopRecording), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func menuStartRecording() {
        if !isRecording {
            startRecording()
        }
    }
    
    @objc func menuStopRecording() {
        if isRecording {
            stopRecording()
        }
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
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,  // Lower quality to reduce file size
            AVEncoderBitRateKey: 32000,  // 32kbps is sufficient for speech
            AVLinearPCMBitDepthKey: 16   // 16-bit audio is sufficient
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordedFileURL!, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            // Set maximum duration to slightly over 1 hour (in seconds)
            audioRecorder?.record(forDuration: 3700) // 1 hour + 100 seconds buffer
            
            isRecording = true
            
            // Update status bar icon and menu items
            if let button = statusItem?.button {
                button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Recording")
            }
            updateMenuItems()
            
            DispatchQueue.main.async {
                self.viewModel.clearTranscriptIfNeeded()
                self.viewModel.appendTranscript("Recording started...")
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
        
        // Update status bar icon and menu items
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Microwhisper")
        }
        updateMenuItems()
        
        DispatchQueue.main.async {
            self.viewModel.appendTranscript("\nRecording stopped. Transcribing...")
            self.viewModel.isRecording = false
        }
        transcribeAudio(fileURL: recordedFileURL!)
    }
    
    private func updateMenuItems() {
        if let menu = statusItem?.menu {
            menu.items.forEach { item in
                switch item.title {
                case "Start Recording":
                    item.isEnabled = !isRecording
                case "Stop Recording":
                    item.isEnabled = isRecording
                default:
                    break
                }
            }
        }
    }
    
    func transcribeAudio(fileURL: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/whisper")
            
            // Optionally suppress all Python warnings
            var env = ProcessInfo.processInfo.environment
            env["PYTHONWARNINGS"] = "ignore"
            process.environment = env
            
            let outputDir = fileURL.deletingLastPathComponent().path
            process.arguments = [
                        fileURL.path,
                        "--model", "base.en",
                        "--output_format", "txt",
                        "--output_dir", outputDir,
                        "--device", "cpu",
                        "--no_speech_threshold", "0.6",
                        "--fp16", "False",
                        "--threads", String(ProcessInfo.processInfo.processorCount),
                        "--beam_size", "1",
                        "--best_of", "1",
                        "--condition_on_previous_text", "False",
                        "--temperature", "0.0",
                        "--initial_prompt", "Transcript:",
                        "--task", "transcribe",            // Force transcribe task
                        "--language", "en"                 // Force English language
                    ]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            DispatchQueue.main.async {
                self.viewModel.appendTranscript("\nStarting transcription (this may take a while for long recordings)...")
            }
            
            do {
                try process.run()
                
                // Set up a timer to check if process is still running and update UI
                var dots = 0
                let progressTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                    guard let self = self else {
                        timer.invalidate()
                        return
                    }
                    
                    dots = (dots + 1) % 4
                    let progressDots = String(repeating: ".", count: dots)
                    DispatchQueue.main.async {
                        // Update the last line of transcript with progress
                        let lines = self.viewModel.transcript.components(separatedBy: "\n")
                        if var lastLine = lines.last, lastLine.contains("transcription") {
                            lastLine = "Processing transcription\(progressDots)"
                            var newTranscript = lines.dropLast().joined(separator: "\n")
                            if !newTranscript.isEmpty {
                                newTranscript += "\n"
                            }
                            newTranscript += lastLine
                            self.viewModel.transcript = newTranscript
                        }
                    }
                }
                
                process.waitUntilExit()
                progressTimer.invalidate()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    DispatchQueue.main.async {
                        self.viewModel.appendTranscript("\nTranscription complete:\n\(output)")
                    }
                } else {
                    // Check for the output file directly
                    let outputFile = (fileURL.deletingPathExtension().path + ".txt")
                    if let transcription = try? String(contentsOfFile: outputFile, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.viewModel.appendTranscript("\nTranscription complete:\n\(transcription)")
                        }
                        // Clean up the output file
                        try? FileManager.default.removeItem(atPath: outputFile)
                    } else {
                        DispatchQueue.main.async {
                            self.viewModel.appendTranscript("\nNo transcription output available.")
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.viewModel.appendTranscript("\nError running transcription: \(error)")
                }
            }
            
            // Clean up the audio file
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
