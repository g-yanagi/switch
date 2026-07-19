import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private let switcher = SwitcherController()
    private lazy var eventTap = EventTapController(switcher: switcher)
    private var statusItem: NSStatusItem?
    private var loginMenuItem: NSMenuItem?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        requestAccessibilityThenStart()
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "⇥"
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Switch — window switcher", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        let login = NSMenuItem(title: "Launch at Login",
                               action: #selector(toggleLoginItem(_:)), keyEquivalent: "")
        login.target = self
        loginMenuItem = login
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func toggleLoginItem(_ sender: NSMenuItem) {
        let enabled = LoginItem.toggle()
        sender.state = enabled ? .on : .off
    }

    // Reflect the current login-item state whenever the menu opens.
    func menuWillOpen(_ menu: NSMenu) {
        loginMenuItem?.state = LoginItem.isEnabled ? .on : .off
    }

    // MARK: - Accessibility permission + tap

    private func requestAccessibilityThenStart() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(opts) {
            startTap()
        } else {
            // Poll until the user grants permission in System Settings.
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
                if AXIsProcessTrusted() {
                    t.invalidate()
                    self?.startTap()
                }
            }
        }
    }

    private func startTap() {
        if !eventTap.start() {
            let alert = NSAlert()
            alert.messageText = "Could not start the event tap"
            alert.informativeText = "Grant Accessibility permission to Switch in System Settings → Privacy & Security → Accessibility, then relaunch."
            alert.runModal()
        }
    }
}
