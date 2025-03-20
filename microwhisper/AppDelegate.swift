import Cocoa
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var viewModel = TranscriptionViewModel()
    private let audioManager = AudioRecorderManager()
    private let statusBarManager = StatusBarManager()
    private let transcriptionManager = TranscriptionManager()
    
    // Track available audio sources
    private(set) var isMicrophoneAvailable = true
    private(set) var isBlackholeAvailable = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupDelegates()
        
        // Start key tap handler
        let keyTapHandler = KeyTapHandler()
        keyTapHandler.startListening(with: self)
    }
    
    private func setupDelegates() {
        viewModel.appDelegate = self
        audioManager.delegate = self
        statusBarManager.delegate = self
        transcriptionManager.delegate = self
    }
}

// MARK: - StatusBarManagerDelegate
extension AppDelegate: StatusBarManagerDelegate {
    func statusBarManagerDidRequestStartRecording() {
        startRecording(from: viewModel.selectedAudioSource)
    }
    
    func statusBarManagerDidRequestStopRecording() {
        audioManager.stopRecording()
    }
    
    func statusBarManagerDidRequestStartRecordingFromMicrophone() {
        startRecording(from: .microphone)
    }
    
    func statusBarManagerDidRequestStartRecordingFromSystemAudio() {
        startRecording(from: .systemAudio)
    }
    
    private func startRecording(from source: AudioRecorderManager.AudioSource) {
        // Check if selected source is available
        if source == .systemAudio && !isBlackholeAvailable {
            DispatchQueue.main.async {
                self.viewModel.appendTranscript("Error: BlackHole audio device not available. Please install BlackHole and restart the app.")
            }
            return
        }
        
        audioManager.startRecording(from: source)
    }
}

// MARK: - AudioRecorderDelegate
extension AppDelegate: AudioRecorderDelegate {    
    func audioRecorderDidDetectDevices(microphoneAvailable: Bool, blackholeAvailable: Bool) {
        isMicrophoneAvailable = microphoneAvailable
        isBlackholeAvailable = blackholeAvailable
        
        // Update the view model
        DispatchQueue.main.async {
            self.viewModel.isBlackholeAvailable = blackholeAvailable
            self.viewModel.isMicrophoneAvailable = microphoneAvailable
            
            // If the currently selected source is not available, switch to an available one
            if self.viewModel.selectedAudioSource == .systemAudio && !blackholeAvailable {
                self.viewModel.selectedAudioSource = .microphone
            }
            
            // Update status bar menu
            self.statusBarManager.updateAudioSourceAvailability(
                microphoneAvailable: microphoneAvailable,
                blackholeAvailable: blackholeAvailable
            )
        }
    }
    func audioRecorderDidStartRecording() {
        statusBarManager.updateRecordingState(isRecording: true)
        DispatchQueue.main.async {
            self.viewModel.clearTranscriptIfNeeded()
            self.viewModel.appendTranscript("Recording started...")
            self.viewModel.isRecording = true
        }
    }
    
    func audioRecorderDidStopRecording(fileURL: URL) {
        statusBarManager.updateRecordingState(isRecording: false)
        DispatchQueue.main.async {
            self.viewModel.appendTranscript("\nRecording stopped. Transcribing...")
            self.viewModel.isRecording = false
        }
        transcriptionManager.transcribeAudio(at: fileURL)
    }
    
    func audioRecorderDidUpdateLevel(_ level: Float) {
        DispatchQueue.main.async {
            self.viewModel.audioLevel = level
        }
    }
    
    func audioRecorderDidFailWithError(_ error: Error) {
        DispatchQueue.main.async {
            self.viewModel.appendTranscript("\nFailed to start recording: \(error)")
        }
    }
}

// MARK: - TranscriptionManagerDelegate
extension AppDelegate: TranscriptionManagerDelegate {
    func transcriptionManager(_ manager: TranscriptionManager, didUpdateProgress progress: String) {
        let lines = viewModel.transcript.components(separatedBy: "\n")
        if var lastLine = lines.last, lastLine.contains("transcription") {
            var newTranscript = lines.dropLast().joined(separator: "\n")
            if !newTranscript.isEmpty {
                newTranscript += "\n"
            }
            newTranscript += progress
            viewModel.transcript = newTranscript
        }
    }
    
    func transcriptionManager(_ manager: TranscriptionManager, didCompleteWithTranscription transcription: String) {
        viewModel.appendTranscript("\nTranscription complete:\n\(transcription)")
    }
    
    func transcriptionManager(_ manager: TranscriptionManager, didFailWithError error: Error) {
        viewModel.appendTranscript("\nError running transcription: \(error)")
    }
}

// MARK: - Public Interface
extension AppDelegate {
    func toggleRecording() {
        if audioManager.isRecording {
            audioManager.stopRecording()
        } else {
            startRecording(from: viewModel.selectedAudioSource)
        }
    }
    
    func setAudioSource(_ source: AudioRecorderManager.AudioSource) {
        viewModel.selectedAudioSource = source
    }
}
