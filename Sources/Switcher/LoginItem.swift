import ServiceManagement

/// Thin wrapper over SMAppService for "launch at login" (macOS 13+).
/// Registers the containing .app bundle as a login item.
enum LoginItem {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Toggle login-at-launch. Returns the resulting enabled state.
    @discardableResult
    static func toggle() -> Bool {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Switch: login item toggle failed: \(error.localizedDescription)")
        }
        return isEnabled
    }
}
