import AppKit
import Foundation

/// Reads the full text of the frontmost focused input field.
///
/// Primary path: `Cmd+A` (select all) → `Cmd+C` (copy) → generation-synchronized pasteboard read.
/// To eliminate race conditions and stale clipboard leakage across application switches,
/// we monitor `NSPasteboard.general.changeCount` and only read when a new copy event has
/// successfully registered. If no copy event occurs within the timeout, `nil` is returned.
final class SelectionReader {
    private let clipboard: ClipboardGateway
    private let selectDelay: TimeInterval = 0.05
    private let pollInterval: TimeInterval = 0.015
    private let maxTimeout: TimeInterval = 0.25

    init(clipboard: ClipboardGateway) {
        self.clipboard = clipboard
    }

    func readFocusedText(completion: @escaping (String?) -> Void) {
        let initialChangeCount = NSPasteboard.general.changeCount

        KeySimulator.selectAll()

        DispatchQueue.main.asyncAfter(deadline: .now() + selectDelay) { [weak self] in
            guard let self else {
                completion(nil)
                return
            }

            KeySimulator.copy()
            let startTime = Date()

            self.pollForPasteboardChange(
                initialCount: initialChangeCount,
                startTime: startTime,
                completion: completion
            )
        }
    }

    private func pollForPasteboardChange(
        initialCount: Int,
        startTime: Date,
        completion: @escaping (String?) -> Void
    ) {
        let currentCount = NSPasteboard.general.changeCount
        if currentCount > initialCount {
            // New copy payload detected on pasteboard
            let copiedText = clipboard.readString()
            completion(copiedText)
            return
        }

        if Date().timeIntervalSince(startTime) >= maxTimeout {
            // Timed out: frontmost field was empty, unselectable, or didn't execute copy.
            // DO NOT fall back to stale clipboard contents!
            completion(nil)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) { [weak self] in
            self?.pollForPasteboardChange(
                initialCount: initialCount,
                startTime: startTime,
                completion: completion
            )
        }
    }
}
