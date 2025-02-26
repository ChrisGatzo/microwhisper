import Cocoa

protocol StatusBarManagerDelegate: AnyObject {
    func statusBarManagerDidRequestStartRecording()
    func statusBarManagerDidRequestStopRecording()
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
        let startItem = NSMenuItem(title: "Start Recording", action: #selector(menuStartRecording), keyEquivalent: "")
        startItem.target = self
        
        let stopItem = NSMenuItem(title: "Stop Recording", action: #selector(menuStopRecording), keyEquivalent: "")
        stopItem.target = self
        stopItem.isEnabled = false
        
        menu.addItem(startItem)
        menu.addItem(stopItem)
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
    
    private func updateMenuItems(isRecording: Bool) {
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
    
    @objc private func menuStartRecording() {
        delegate?.statusBarManagerDidRequestStartRecording()
    }
    
    @objc private func menuStopRecording() {
        delegate?.statusBarManagerDidRequestStopRecording()
    }
} 