import AppKit

/// A small, non-activating status overlay shown briefly near the top of the screen.
final class TranslationHUD {
    static let shared = TranslationHUD()

    private var panel: NSPanel?
    private var label: NSTextField?
    private var dismissWorkItem: DispatchWorkItem?

    private init() {}

    func show(message: String, autoDismiss: Bool = true) {
        DispatchQueue.main.async { [weak self] in
            self?.display(message: message, autoDismiss: autoDismiss)
        }
    }

    private func display(message: String, autoDismiss: Bool) {
        dismissWorkItem?.cancel()

        if panel == nil {
            let size = NSSize(width: 300, height: 48)
            let p = NSPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.level = .statusBar
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.ignoresMouseEvents = true

            let container = NSView(frame: NSRect(origin: .zero, size: size))
            container.wantsLayer = true
            container.layer?.cornerRadius = 12
            container.layer?.backgroundColor = NSColor.windowBackgroundColor
                .withAlphaComponent(0.95).cgColor

            let l = NSTextField(labelWithString: "")
            l.alignment = .center
            l.font = .systemFont(ofSize: 13, weight: .medium)
            l.textColor = .labelColor
            l.lineBreakMode = .byTruncatingTail
            l.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(l)
            NSLayoutConstraint.activate([
                l.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                l.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                l.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 12),
                l.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -12)
            ])

            p.contentView = container
            panel = p
            label = l
        }

        label?.stringValue = message
        panel?.contentView?.layoutSubtreeIfNeeded()

        if let screen = NSScreen.main {
            let panelSize = panel?.frame.size ?? NSSize(width: 300, height: 48)
            let x = screen.frame.midX - panelSize.width / 2
            let y = screen.frame.maxY - 110
            panel?.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel?.orderFrontRegardless()

        if autoDismiss {
            let item = DispatchWorkItem { [weak self] in
                self?.panel?.orderOut(nil)
            }
            dismissWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: item)
        }
    }
}
