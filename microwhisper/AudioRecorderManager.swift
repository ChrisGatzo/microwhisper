import AVFoundation

protocol AudioRecorderDelegate: AnyObject {
    func audioRecorderDidStartRecording()
    func audioRecorderDidStopRecording(fileURL: URL)
    func audioRecorderDidUpdateLevel(_ level: Float)
    func audioRecorderDidFailWithError(_ error: Error)
}

class AudioRecorderManager: NSObject, AVAudioRecorderDelegate {
    weak var delegate: AudioRecorderDelegate?
    private var audioRecorder: AVAudioRecorder?
    private var recordedFileURL: URL?
    private var meterTimer: Timer?
    private(set) var isRecording = false
    
    private let audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 16000,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        AVEncoderBitRateKey: 32000,
        AVLinearPCMBitDepthKey: 16
    ]
    
    func startRecording() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording-\(UUID().uuidString).m4a"
        recordedFileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordedFileURL!, settings: audioSettings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record(forDuration: 3700) // 1 hour + 100 seconds buffer
            
            isRecording = true
            delegate?.audioRecorderDidStartRecording()
            startMeterTimer()
        } catch {
            delegate?.audioRecorderDidFailWithError(error)
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        meterTimer?.invalidate()
        meterTimer = nil
        isRecording = false
        
        if let fileURL = recordedFileURL {
            delegate?.audioRecorderDidStopRecording(fileURL: fileURL)
        }
    }
    
    private func startMeterTimer() {
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true, block: { [weak self] timer in
            guard let self = self,
                  let recorder = self.audioRecorder,
                  recorder.isRecording else {
                timer.invalidate()
                return
            }
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0)
            let level = max(0, min(1, (power + 50) / 50))
            self.delegate?.audioRecorderDidUpdateLevel(level)
        })
    }
} 