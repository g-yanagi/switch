import AppKit

// Menu-bar / accessory app: no Dock icon, stays resident and lightweight.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
