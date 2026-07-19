import AppKit

/// Borderless floating panel that lists switchable windows.
/// Never becomes key, so the target app keeps focus until we raise a window.
final class OverlayWindow {

    private let window: NSPanel
    private let view: OverlayView
    private let highlight = HighlightWindow()

    private let rowHeight: CGFloat = 34
    private let padding: CGFloat = 10
    private let width: CGFloat = 460

    init() {
        view = OverlayView()
        window = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        window.isFloatingPanel = true
        window.level = .popUpMenu
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.contentView = view
    }

    func update(items: [WindowInfo], selected: Int) {
        view.items = items
        view.selected = selected
        view.rowHeight = rowHeight
        view.padding = padding
        view.needsDisplay = true

        let height = CGFloat(max(items.count, 1)) * rowHeight + padding * 2
        if let screen = NSScreen.main {
            let f = screen.frame
            let origin = NSPoint(
                x: f.midX - width / 2,
                y: f.midY - height / 2
            )
            window.setFrame(NSRect(x: origin.x, y: origin.y, width: width, height: height), display: true)
        }

        // Frame the selected window on screen, then keep the list on top.
        if items.indices.contains(selected), let frame = items[selected].frame {
            highlight.show(axFrame: frame)
        } else {
            highlight.hide()
        }
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
        highlight.hide()
    }
}

/// A borderless, click-through panel that draws a thick border around the
/// selected window's actual on-screen location.
final class HighlightWindow {

    private let window: NSPanel
    private let view = HighlightView()

    init() {
        window = NSPanel(contentRect: .zero,
                         styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: true)
        window.isFloatingPanel = true
        window.level = .popUpMenu
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.contentView = view
    }

    /// - Parameter axFrame: window frame in AX (top-left origin) coordinates.
    func show(axFrame: CGRect) {
        guard let primary = NSScreen.screens.first else { return }
        // Convert AX top-left origin to Cocoa bottom-left origin.
        let cocoaY = primary.frame.height - axFrame.origin.y - axFrame.size.height
        let rect = NSRect(x: axFrame.origin.x, y: cocoaY,
                          width: axFrame.size.width, height: axFrame.size.height)
        window.setFrame(rect.insetBy(dx: -3, dy: -3), display: true)
        view.needsDisplay = true
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }
}

final class HighlightView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let lineWidth: CGFloat = 4
        let rect = bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        path.lineWidth = lineWidth
        NSColor.controlAccentColor.setStroke()
        path.stroke()
    }
}

/// Custom-drawn list: app icon + "AppName — Title", with the selected row highlighted.
final class OverlayView: NSView {

    var items: [WindowInfo] = []
    var selected = 0
    var rowHeight: CGFloat = 34
    var padding: CGFloat = 10

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // Rounded translucent background.
        let bg = NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12)
        NSColor.windowBackgroundColor.withAlphaComponent(0.96).setFill()
        bg.fill()

        let iconSize: CGFloat = 22
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.labelColor
        ]

        for (i, item) in items.enumerated() {
            let rowRect = NSRect(x: padding,
                                 y: padding + CGFloat(i) * rowHeight,
                                 width: bounds.width - padding * 2,
                                 height: rowHeight)

            if i == selected {
                let sel = NSBezierPath(roundedRect: rowRect.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
                NSColor.selectedContentBackgroundColor.setFill()
                sel.fill()
            }

            let iconRect = NSRect(x: rowRect.minX + 8,
                                  y: rowRect.midY - iconSize / 2,
                                  width: iconSize, height: iconSize)
            item.icon?.draw(in: iconRect)

            let label = item.title.isEmpty ? item.appName : "\(item.appName) — \(item.title)"
            let attrs = i == selected
                ? textAttrs.merging([.foregroundColor: NSColor.selectedMenuItemTextColor]) { $1 }
                : textAttrs
            let textRect = NSRect(x: iconRect.maxX + 10,
                                  y: rowRect.midY - 9,
                                  width: rowRect.maxX - (iconRect.maxX + 10) - 8,
                                  height: 18)
            (label as NSString).draw(in: textRect, withAttributes: attrs)
        }
    }
}
