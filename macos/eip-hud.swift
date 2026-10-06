// eip-hud: show a label next to the mouse cursor until the next click.
//
// Usage: eip-hud <title> [url] [description]
//
// The label never takes focus from the frontmost app. Clicking anywhere else or
// switching apps closes it; clicking the label opens <url> (when given) and
// closes it.
//
// Build: ./install.sh, or swiftc -O eip-hud.swift -o ~/.local/bin/eip-hud

import AppKit

/// Upper bound on lifetime, so a label nobody clicks away doesn't stay up forever.
let maxLifetimeSeconds: TimeInterval = 300
let maxTextWidth: CGFloat = 400
let cornerRadius: CGFloat = 10

/// Rounded-rect mask; NSVisualEffectView ignores a layer's cornerRadius.
func roundedMask(radius: CGFloat) -> NSImage {
    let edge = radius * 2 + 1
    let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
        NSColor.black.setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        return true
    }
    image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
    image.resizingMode = .stretch
    return image
}

final class HudView: NSVisualEffectView {
    var onClick: () -> Void = {}

    // The app is never active, so the first click must count.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    // Claim every click, so the labels inside don't swallow it.
    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }
    override func mouseDown(with event: NSEvent) { onClick() }
}

@MainActor
final class Hud {
    let panel: NSPanel
    var clickMonitor: Any?

    init(title: String, url: URL?, description: String) {
        let titleField = NSTextField(wrappingLabelWithString: title)
        titleField.font = .boldSystemFont(ofSize: 13)
        titleField.textColor = .labelColor
        titleField.preferredMaxLayoutWidth = maxTextWidth
        titleField.isSelectable = false

        var rows: [NSView] = [titleField]
        if !description.isEmpty {
            let descriptionField = NSTextField(wrappingLabelWithString: description)
            descriptionField.font = .systemFont(ofSize: 12)
            descriptionField.textColor = .secondaryLabelColor
            descriptionField.preferredMaxLayoutWidth = maxTextWidth
            descriptionField.isSelectable = false
            rows.append(descriptionField)
        }
        if let host = url?.host {
            let sourceField = NSTextField(labelWithString: host)
            sourceField.font = .systemFont(ofSize: 11)
            sourceField.textColor = .tertiaryLabelColor
            rows.append(sourceField)
        }
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 3
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        let size = stack.fittingSize

        let view = HudView(frame: NSRect(origin: .zero, size: size))
        view.material = .popover
        view.blendingMode = .behindWindow
        // Otherwise it renders as an inactive (flat) window, since we never activate.
        view.state = .active
        view.maskImage = roundedMask(radius: cornerRadius)
        stack.frame = view.bounds
        view.addSubview(stack)
        view.onClick = {
            if let url { NSWorkspace.shared.open(url) }
            exit(0)
        }

        panel = NSPanel(
            contentRect: NSRect(origin: Hud.origin(for: size), size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.contentView = view
    }

    /// Below-right of the cursor; above it when that would run off the bottom.
    static func origin(for size: NSSize) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        var origin = NSPoint(x: mouse.x + 12, y: mouse.y - size.height - 16)
        guard let visible = screen?.visibleFrame else { return origin }
        if origin.y < visible.minY { origin.y = mouse.y + 16 }
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        return origin
    }

    func show() {
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.invalidateShadow()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1
        }

        // A global monitor sees clicks delivered to other apps, i.e. every click
        // that isn't on the label. Mouse monitors need no Accessibility
        // permission; only key monitors do.
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: clicks) { _ in exit(0) }

        // Switching apps (Cmd-Tab, Dock, ...) closes it too.
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if app?.processIdentifier != getpid() { exit(0) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + maxLifetimeSeconds) { exit(0) }
    }
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: eip-hud <title> [url] [description]\n".utf8))
    exit(2)
}
let url = args.count >= 3 && !args[2].isEmpty ? URL(string: args[2]) : nil
let description = args.count >= 4 ? args[3] : ""

MainActor.assumeIsolated {
    let app = NSApplication.shared
    // No Dock icon, no menu bar, never becomes the active app.
    app.setActivationPolicy(.accessory)
    let hud = Hud(title: args[1], url: url, description: description)
    hud.show()
    app.run()
}
