import AppKit
import CoreGraphics

/// Installs a session-level event tap that intercepts Cmd+Tab before the
/// system App Switcher sees it, and reports Cmd release / Escape.
final class EventTapController {

    private let switcher: SwitcherController
    private var tap: CFMachPort?

    private let kVK_Tab: Int64 = 48
    private let kVK_Escape: Int64 = 53

    init(switcher: SwitcherController) {
        self.switcher = switcher
    }

    @discardableResult
    func start() -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,           // may consume events
            eventsOfInterest: CGEventMask(mask),
            callback: eventTapCallback,
            userInfo: refcon
        ) else {
            return false
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func reEnable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    /// Returns nil to consume the event, or the event to pass it through.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            if keyCode == kVK_Tab && flags.contains(.maskCommand) {
                switcher.handleTab(backwards: flags.contains(.maskShift))
                return nil // swallow: system App Switcher never appears
            }
            if keyCode == kVK_Escape && switcher.isActive {
                switcher.cancel()
                return nil
            }
            return Unmanaged.passUnretained(event)

        case .flagsChanged:
            if switcher.isActive && !event.flags.contains(.maskCommand) {
                switcher.commit()
            }
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }
}

private func eventTapCallback(proxy: CGEventTapProxy,
                              type: CGEventType,
                              event: CGEvent,
                              userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let controller = Unmanaged<EventTapController>.fromOpaque(userInfo).takeUnretainedValue()

    // macOS disables the tap on timeout / user input; re-enable and pass through.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        controller.reEnable()
        return Unmanaged.passUnretained(event)
    }
    return controller.handle(type: type, event: event)
}
