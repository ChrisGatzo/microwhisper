import Cocoa

protocol StatusBarManagerDelegate: AnyObject {
    func statusBarManagerDidRequestStartRecording()
    func statusBarManagerDidRequestStopRecording()
    func statusBarManagerDidRequestStartRecordingFromMicrophone()
    func statusBarManagerDidRequestStartRecordingFromSystemAudio()
}

class StatusBarManager: NSObject {
    private var statusItem: NSStatusItem?
    weak var delegate: StatusBarManagerDelegate?
    
    override init() {
        super.init()
        setupStatusBarItem()
    }
    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Microwhisper")
        }
        
        let menu = NSMenu()
        
        // Recording controls
        let startItem = NSMenuItem(title: "Start Recording", action: #selector(menuStartRecording), keyEquivalent: "")
        startItem.target = self
        
        let stopItem = NSMenuItem(title: "Stop Recording", action: #selector(menuStopRecording), keyEquivalent: "")
        stopItem.target = self
        stopItem.isEnabled = false
        
        menu.addItem(startItem)
        menu.addItem(stopItem)
        menu.addItem(NSMenuItem.separator())
        
        // Audio source submenu
        let sourceSubmenu = NSMenu()
        
        let microphoneItem = NSMenuItem(title: "Microphone", action: #selector(menuSelectMicrophone), keyEquivalent: "")
        microphoneItem.target = self
        microphoneItem.state = .on
        
        let systemAudioItem = NSMenuItem(title: "System Audio (BlackHole)", action: #selector(menuSelectSystemAudio), keyEquivalent: "")
        systemAudioItem.target = self
        
        sourceSubmenu.addItem(microphoneItem)
        sourceSubmenu.addItem(systemAudioItem)
        
        let sourceItem = NSMenuItem(title: "Audio Source", action: nil, keyEquivalent: "")
        sourceItem.submenu = sourceSubmenu
        
        menu.addItem(sourceItem)
        
        // Quick actions
        menu.addItem(NSMenuItem.separator())
        
        let recordMicItem = NSMenuItem(title: "Record from Microphone", action: #selector(menuRecordFromMicrophone), keyEquivalent: "")
        recordMicItem.target = self
        
        let recordSystemItem = NSMenuItem(title: "Record from System Audio", action: #selector(menuRecordFromSystemAudio), keyEquivalent: "")
        recordSystemItem.target = self
        
        menu.addItem(recordMicItem)
        menu.addItem(recordSystemItem)
        
        // Quit option
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    func updateRecordingState(isRecording: Bool) {
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: isRecording ? "mic.fill" : "mic", 
                                 accessibilityDescription: isRecording ? "Recording" : "Microwhisper")
        }
        updateMenuItems(isRecording: isRecording)
    }
    
    func updateAudioSourceAvailability(microphoneAvailable: Bool, blackholeAvailable: Bool) {
        if let menu = statusItem?.menu {
            // Update the Audio Source submenu
            if let sourceItem = menu.items.first(where: { $0.title == "Audio Source" }),
               let sourceSubmenu = sourceItem.submenu {
                
                // Update system audio item
                if let systemAudioItem = sourceSubmenu.items.first(where: { $0.title == "System Audio (BlackHole)" }) {
                    systemAudioItem.isEnabled = blackholeAvailable
                }
            }
            
            // Update quick action items
            if let recordSystemItem = menu.items.first(where: { $0.title == "Record from System Audio" }) {
                recordSystemItem.isEnabled = blackholeAvailable
            }
        }
    }
    
    private func updateMenuItems(isRecording: Bool) {
        if let menu = statusItem?.menu {
            menu.items.forEach { item in
                switch item.title {
                case "Start Recording":
                    item.isEnabled = !isRecording
                case "Stop Recording":
                    item.isEnabled = isRecording
                case "Record from Microphone", "Record from System Audio":
                    item.isEnabled = !isRecording
                case "Audio Source":
                    item.isEnabled = !isRecording
                default:
                    break
                }
            }
        }
    }
    
    @objc private func menuStartRecording() {
        delegate?.statusBarManagerDidRequestStartRecording()
    }
    
    @objc private func menuStopRecording() {
        delegate?.statusBarManagerDidRequestStopRecording()
    }
    
    @objc private func menuSelectMicrophone() {
        updateSourceMenuState(selectedSource: "Microphone")
    }
    
    @objc private func menuSelectSystemAudio() {
        updateSourceMenuState(selectedSource: "System Audio (BlackHole)")
    }
    
    @objc private func menuRecordFromMicrophone() {
        delegate?.statusBarManagerDidRequestStartRecordingFromMicrophone()
    }
    
    @objc private func menuRecordFromSystemAudio() {
        delegate?.statusBarManagerDidRequestStartRecordingFromSystemAudio()
    }
    
    private func updateSourceMenuState(selectedSource: String) {
        if let menu = statusItem?.menu,
           let sourceItem = menu.items.first(where: { $0.title == "Audio Source" }),
           let sourceSubmenu = sourceItem.submenu {
            
            sourceSubmenu.items.forEach { item in
                item.state = (item.title == selectedSource) ? .on : .off
            }
        }
    }
}