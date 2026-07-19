import AppKit

/// Owns the switcher state machine and MRU ordering.
/// Driven entirely from the main thread (event tap runs on the main run loop).
final class SwitcherController {

    private let overlay = OverlayWindow()
    private var items: [WindowInfo] = []
    private var selected = 0
    private(set) var isActive = false

    /// Most-recently-used order, newest first, keyed by CGWindowID.
    private var mru: [CGWindowID] = []

    // MARK: - Input handling

    /// Cmd+Tab (backwards = Shift held). Opens the switcher or advances selection.
    func handleTab(backwards: Bool) {
        if !isActive {
            begin()
        }
        guard !items.isEmpty else { return }
        if backwards {
            selected = (selected - 1 + items.count) % items.count
        } else {
            selected = (selected + 1) % items.count
        }
        overlay.update(items: items, selected: selected)
    }

    /// Cmd released: commit the current selection.
    func commit() {
        guard isActive else { return }
        isActive = false
        overlay.hide()
        guard items.indices.contains(selected) else { return }
        let target = items[selected]
        moveToFront(target.windowID)
        WindowEnumerator.raise(target)
    }

    /// Escape: cancel without changing the front window.
    func cancel() {
        guard isActive else { return }
        isActive = false
        overlay.hide()
    }

    // MARK: - Internals

    private func begin() {
        // Make sure the window the user is currently on is MRU-front,
        // so index 0 = current window and index 1 = previous window.
        if let frontID = WindowEnumerator.frontmostWindowID() {
            moveToFront(frontID)
        }
        items = orderedWindows()
        // Start on the current window; handleTab() advances by one, so the first
        // Cmd+Tab lands on the previous window (index 1) for a two-window toggle.
        selected = 0
        isActive = true
    }

    private func orderedWindows() -> [WindowInfo] {
        let windows = WindowEnumerator.enumerate()
        let rank: (CGWindowID) -> Int = { id in self.mru.firstIndex(of: id) ?? Int.max }
        return windows.enumerated()
            .sorted { lhs, rhs in
                let rl = rank(lhs.element.windowID), rr = rank(rhs.element.windowID)
                return rl != rr ? rl < rr : lhs.offset < rhs.offset
            }
            .map { $0.element }
    }

    private func moveToFront(_ id: CGWindowID) {
        mru.removeAll { $0 == id }
        mru.insert(id, at: 0)
    }
}
