import Cocoa

class KeyTapHandler {
    private var eventTap: CFMachPort?
    
    func startListening(with delegate: AppDelegate) {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let flags = event.flags
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                // "R" key has keyCode 15.
                if keyCode == 15 && flags.contains(.maskAlternate) && flags.contains(.maskShift) {
                    DispatchQueue.main.async {
                        let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon!).takeUnretainedValue()
                        delegate.toggleRecording()
                    }
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(delegate).toOpaque())
        )
        guard let eventTap = eventTap else {
            print("Failed to create event tap.")
            return
        }
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
    
    func stopListening() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        eventTap = nil
    }
}
