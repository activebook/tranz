import Foundation

/// Replaces the current selection (the whole field, per v1 scope) with translated text.
///
/// The translation is written to the pasteboard, then `Cmd+V` pastes it over the
/// still-selected original text. Natural `Cmd+Z` undo reverts the replacement.
/// To ensure target applications (e.g. Electron apps, browsers, text editors) have fully
/// consumed the pasteboard payload before clipboard restoration occurs, a safe event-drain
/// window is provided before invoking completion.
final class Replacer {
    private let clipboard: ClipboardGateway
    private let pasteDelay: TimeInterval = 0.04
    private let drainWindow: TimeInterval = 0.15

    init(clipboard: ClipboardGateway) {
        self.clipboard = clipboard
    }

    func replaceWith(_ text: String, completion: @escaping () -> Void) {
        clipboard.write(text)
        DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay) { [weak self] in
            KeySimulator.paste()
            DispatchQueue.main.asyncAfter(deadline: .now() + (self?.drainWindow ?? 0.15)) {
                completion()
            }
        }
    }
}
