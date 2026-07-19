import AppKit
import ApplicationServices

/// Private AX SPI that maps an AXUIElement window to its CGWindowID.
/// Widely used (e.g. AltTab) to get a stable per-window identifier.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement,
                                   _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

struct WindowInfo {
    let windowID: CGWindowID
    let axWindow: AXUIElement
    let pid: pid_t
    let appName: String
    let title: String
    let icon: NSImage?
    /// Window frame in AX (top-left origin) screen coordinates.
    let frame: CGRect?
}

enum WindowEnumerator {

    /// Enumerate all standard, non-minimized windows of regular applications.
    static func enumerate() -> [WindowInfo] {
        var result: [WindowInfo] = []
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated
        }
        for app in apps {
            let pid = app.processIdentifier
            let axApp = AXUIElementCreateApplication(pid)
            var windowsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let windows = windowsRef as? [AXUIElement] else { continue }

            for w in windows {
                guard isStandardVisibleWindow(w) else { continue }
                var wid: CGWindowID = 0
                guard _AXUIElementGetWindow(w, &wid) == .success, wid != 0 else { continue }
                result.append(WindowInfo(
                    windowID: wid,
                    axWindow: w,
                    pid: pid,
                    appName: app.localizedName ?? "",
                    title: axString(w, kAXTitleAttribute) ?? "",
                    icon: app.icon,
                    frame: axFrame(w)
                ))
            }
        }
        return result
    }

    /// The CGWindowID of the currently focused window of the frontmost app, if any.
    static func frontmostWindowID() -> CGWindowID? {
        guard let front = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(front.processIdentifier)
        var winRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &winRef) == .success
        else { return nil }
        let w = winRef as! AXUIElement
        var wid: CGWindowID = 0
        guard _AXUIElementGetWindow(w, &wid) == .success, wid != 0 else { return nil }
        return wid
    }

    /// Raise a specific window and activate its owning app, so switching is per-window.
    static func raise(_ info: WindowInfo) {
        AXUIElementPerformAction(info.axWindow, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(info.axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        NSRunningApplication(processIdentifier: info.pid)?.activate()
    }

    // MARK: - Helpers

    private static func isStandardVisibleWindow(_ w: AXUIElement) -> Bool {
        guard axString(w, kAXSubroleAttribute) == (kAXStandardWindowSubrole as String) else { return false }
        if axBool(w, kAXMinimizedAttribute) == true { return false }
        return true
    }

    private static func axString(_ e: AXUIElement, _ attr: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(e, attr as CFString, &ref) == .success else { return nil }
        return ref as? String
    }

    private static func axBool(_ e: AXUIElement, _ attr: String) -> Bool? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(e, attr as CFString, &ref) == .success else { return nil }
        return (ref as? Bool)
    }

    private static func axFrame(_ e: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(e, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(e, kAXSizeAttribute as CFString, &sizeRef) == .success
        else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }
}
