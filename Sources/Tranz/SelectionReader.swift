import Foundation

/// Reads the full text of the frontmost focused input field.
///
/// Primary path: `Cmd+A` (select all) → `Cmd+C` (copy) → read the pasteboard.
/// This is universal across browser inputs, native apps, and Electron apps.
/// The caller must save the clipboard before invoking and restore it afterwards.
final class SelectionReader {
    private let clipboard: ClipboardGateway
    private let delay: TimeInterval = 0.08

    init(clipboard: ClipboardGateway) {
        self.clipboard = clipboard
    }

    func readFocusedText(completion: @escaping (String?) -> Void) {
        KeySimulator.selectAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            KeySimulator.copy()
            DispatchQueue.main.asyncAfter(deadline: .now() + (self?.delay ?? 0.08)) {
                completion(self?.clipboard.readString())
            }
        }
    }
}
