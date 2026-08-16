import Foundation

/// Replaces the current selection (the whole field, per v1 scope) with translated text.
///
/// The translation is written to the pasteboard, then `Cmd+V` pastes it over the
/// still-selected original text. Natural `Cmd+Z` undo reverts the replacement.
final class Replacer {
    private let clipboard: ClipboardGateway

    init(clipboard: ClipboardGateway) {
        self.clipboard = clipboard
    }

    func replaceWith(_ text: String, completion: @escaping () -> Void) {
        clipboard.write(text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            KeySimulator.paste()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                completion()
            }
        }
    }
}
