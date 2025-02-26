import Foundation

protocol TranscriptionManagerDelegate: AnyObject {
    func transcriptionManager(_ manager: TranscriptionManager, didUpdateProgress progress: String)
    func transcriptionManager(_ manager: TranscriptionManager, didCompleteWithTranscription transcription: String)
    func transcriptionManager(_ manager: TranscriptionManager, didFailWithError error: Error)
}

class TranscriptionManager {
    weak var delegate: TranscriptionManagerDelegate?
    private var progressTimer: Timer?
    
    func transcribeAudio(at fileURL: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/whisper")
            
            var env = ProcessInfo.processInfo.environment
            env["PYTHONWARNINGS"] = "ignore"
            process.environment = env
            
            let outputDir = fileURL.deletingLastPathComponent().path
            process.arguments = self.createWhisperArguments(for: fileURL, outputDir: outputDir)
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                self.startProgressTimer()
                
                process.waitUntilExit()
                self.progressTimer?.invalidate()
                
                try self.handleTranscriptionOutput(pipe: pipe, fileURL: fileURL)
            } catch {
                DispatchQueue.main.async {
                    self.delegate?.transcriptionManager(self, didFailWithError: error)
                }
            }
            
            // Clean up the audio file
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    private func createWhisperArguments(for fileURL: URL, outputDir: String) -> [String] {
        return [
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
            "--task", "transcribe",
            "--language", "en"
        ]
    }
    
    private func startProgressTimer() {
        var dots = 0
        progressTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            dots = (dots + 1) % 4
            let progressDots = String(repeating: ".", count: dots)
            DispatchQueue.main.async {
                self.delegate?.transcriptionManager(self, didUpdateProgress: "Processing transcription\(progressDots)")
            }
        }
    }
    
    private func handleTranscriptionOutput(pipe: Pipe, fileURL: URL) throws {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8), !output.isEmpty {
            DispatchQueue.main.async {
                self.delegate?.transcriptionManager(self, didCompleteWithTranscription: output)
            }
        } else {
            // Check for the output file directly
            let outputFile = (fileURL.deletingPathExtension().path + ".txt")
            if let transcription = try? String(contentsOfFile: outputFile, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.delegate?.transcriptionManager(self, didCompleteWithTranscription: transcription)
                }
                // Clean up the output file
                try? FileManager.default.removeItem(atPath: outputFile)
            } else {
                DispatchQueue.main.async {
                    self.delegate?.transcriptionManager(self, didCompleteWithTranscription: "No transcription output available.")
                }
            }
        }
    }
} 