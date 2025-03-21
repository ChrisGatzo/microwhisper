import AVFoundation
import CoreAudio

protocol AudioRecorderDelegate: AnyObject {
    func audioRecorderDidStartRecording()
    func audioRecorderDidStopRecording(fileURL: URL)
    func audioRecorderDidUpdateLevel(_ level: Float)
    func audioRecorderDidFailWithError(_ error: Error)
    func audioRecorderDidDetectDevices(microphoneAvailable: Bool, blackholeAvailable: Bool)
}

class AudioRecorderManager: NSObject, AVAudioRecorderDelegate {
    weak var delegate: AudioRecorderDelegate?
    private var audioRecorder: AVAudioRecorder?
    private var recordedFileURL: URL?
    private var meterTimer: Timer?
    private(set) var isRecording = false
    
    // Audio source selection
    enum AudioSource {
        case microphone
        case systemAudio
        case both
    }
    
    private(set) var currentAudioSource: AudioSource = .microphone
    private(set) var isBlackholeAvailable = false
    
    // Audio device properties
    private let blackholeDeviceName = "MicroWhisper Input"
    private var blackholeDeviceID: AudioDeviceID?
    private var defaultInputDeviceID: AudioDeviceID = 0
    
    private let audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 16000,
        AVNumberOfChannelsKey: 2, // Changed to stereo for system audio
        AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        AVEncoderBitRateKey: 64000, // Increased for better quality
        AVLinearPCMBitDepthKey: 16
    ]
    
    override init() {
        super.init()
        setupDeviceListener()
        detectAudioDevices()
    }
    
    deinit {
        removeDeviceListener()
    }
    private func setupDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertySelectorWildcard,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementWildcard)
        
        let status = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            { (_, _, _, context) -> OSStatus in
                let manager = Unmanaged<AudioRecorderManager>.fromOpaque(context!).takeUnretainedValue()
                manager.detectAudioDevices()
                return noErr
            },
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        
        if status != noErr {
            print("Error setting up device listener: \(status)")
        }
    }
    
    private func removeDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertySelectorWildcard,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementWildcard)
        
        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            { (_, _, _, context) -> OSStatus in
                let manager = Unmanaged<AudioRecorderManager>.fromOpaque(context!).takeUnretainedValue()
                manager.detectAudioDevices()
                return noErr
            },
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
    }
    
    func startRecording(from source: AudioSource = .microphone) {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording-\(UUID().uuidString).m4a"
        recordedFileURL = tempDir.appendingPathComponent(fileName)
        
        // Set the current audio source
        currentAudioSource = source
        
        do {
            // Configure audio device based on selected source
            try configureAudioDevice(for: source)
            
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
    
    private func configureAudioDevice(for source: AudioSource) throws {
        var deviceID: AudioDeviceID
        
        switch source {
        case .microphone:
            // Always allow switching to microphone, using default input device
            deviceID = defaultInputDeviceID
            print("Switching to microphone input: ID \(deviceID)")
            
        case .systemAudio:
            guard let blackholeID = blackholeDeviceID, isBlackholeAvailable else {
                throw NSError(domain: "AudioRecorderManager", 
                              code: 1001, 
                              userInfo: [NSLocalizedDescriptionKey: "BlackHole audio device not available"])
            }
            deviceID = blackholeID
            print("Switching to system audio input: ID \(deviceID)")
            
        case .both:
            throw NSError(domain: "AudioRecorderManager", 
                          code: 1003, 
                          userInfo: [NSLocalizedDescriptionKey: "Recording from both sources simultaneously is not implemented yet"])
        }
        
        // Set the selected device as the default input device
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            size,
            &deviceID)
        
        if status != noErr {
            throw NSError(domain: "AudioRecorderManager", 
                          code: Int(status), 
                          userInfo: [NSLocalizedDescriptionKey: "Failed to set audio input device"])
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        meterTimer?.invalidate()
        meterTimer = nil
        isRecording = false
        
        // Reset to default input device
        do {
            try configureAudioDevice(for: .microphone)
        } catch {
            print("Error resetting audio device: \(error)")
        }
        
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
            
            // Get power level based on audio source
            var power: Float = 0.0
            
            switch self.currentAudioSource {
            case .microphone, .systemAudio:
                power = recorder.averagePower(forChannel: 0)
            case .both:
                // If we're recording from both sources, average the channels
                let channel0Power = recorder.averagePower(forChannel: 0)
                let channel1Power = recorder.averagePower(forChannel: 1)
                power = (channel0Power + channel1Power) / 2.0
            }
            
            // Convert power to level (0.0 to 1.0)
            let level = max(0, min(1, (power + 50) / 50))
            self.delegate?.audioRecorderDidUpdateLevel(level)
        })
    }
    
    // MARK: - Device Detection
    
    func detectAudioDevices() {
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        var result = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize)
        
        if result != noErr {
            print("Error getting devices property size: \(result)")
            updateDeviceAvailability(microphoneAvailable: true, blackholeAvailable: false)
            return
        }
        
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        result = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &deviceIDs)
        
        if result != noErr {
            print("Error getting device IDs: \(result)")
            updateDeviceAvailability(microphoneAvailable: true, blackholeAvailable: false)
            return
        }
        
        // Get default input device
        address.mSelector = kAudioHardwarePropertyDefaultInputDevice
        var defaultDeviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        result = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &defaultDeviceID)
        
        if result == noErr {
            defaultInputDeviceID = defaultDeviceID
        }
        
        // Check each device for BlackHole
        var blackholeFound = false
        
        for deviceID in deviceIDs {
            // Get device name
            address.mSelector = kAudioDevicePropertyDeviceNameCFString
            var deviceName: Unmanaged<CFString>?
            size = UInt32(MemoryLayout<CFString>.size)
            
            result = AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &size,
                &deviceName)
            
            if result == noErr, let cfName = deviceName?.takeRetainedValue() {
                let name = cfName as String
                if name.contains(blackholeDeviceName) {
                    blackholeFound = true
                    blackholeDeviceID = deviceID
                    break // Found what we need, exit the loop
                }
            }
        }
        
        // Always consider microphone available - we want users to be able to 
        // switch back to microphone even if none is detected
        let microphoneAlwaysAvailable = true
        
        // Update state and notify delegate
        isBlackholeAvailable = blackholeFound
        updateDeviceAvailability(microphoneAvailable: microphoneAlwaysAvailable, blackholeAvailable: blackholeFound)
    }
    
    private func updateDeviceAvailability(microphoneAvailable: Bool, blackholeAvailable: Bool) {
        DispatchQueue.main.async {
            self.delegate?.audioRecorderDidDetectDevices(
                microphoneAvailable: microphoneAvailable,
                blackholeAvailable: blackholeAvailable
            )
        }
    }
    
    @objc private func handleAudioRouteChange(notification: Notification) {
        // When audio routes change, re-detect devices
        detectAudioDevices()
    }
}