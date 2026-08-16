import Foundation

/// Orchestrates the full translation cycle described in §3.1:
///
///     save clipboard → Cmd+A → Cmd+C → read text → restore clipboard
///     → translate (async) → save clipboard → write translation → Cmd+V → restore clipboard
///
/// The clipboard is restored immediately after reading the text (rather than only at
/// the very end) so the user's clipboard stays intact during the network round-trip.
final class TranslationCoordinator {
    static let shared = TranslationCoordinator()

    private let clipboard = ClipboardGateway()
    private let reader: SelectionReader
    private let replacer: Replacer
    private let translator = Translator()
    private var isTranslating = false

    private init() {
        reader = SelectionReader(clipboard: clipboard)
        replacer = Replacer(clipboard: clipboard)
    }

    func performTranslation() {
        let settings = AppSettings.shared

        guard AccessibilityPermissionCoordinator.shared.isTrusted else {
            _ = AccessibilityPermissionCoordinator.shared.requestIfNeeded()
            TranslationHUD.shared.show(message: "Enable Accessibility permission, then relaunch")
            return
        }

        guard settings.isConfigured else {
            TranslationHUD.shared.show(message: "Set endpoint URL & model in Settings")
            return
        }

        guard !isTranslating else { return }
        isTranslating = true

        TranslationHUD.shared.show(message: "Translating…", autoDismiss: false)
        clipboard.save()

        reader.readFocusedText { [weak self] text in
            guard let self else { return }
            // Restore the user's real clipboard before the network call.
            self.clipboard.restore()

            guard let text, !text.isEmpty else {
                self.isTranslating = false
                TranslationHUD.shared.show(message: "No text in focused field")
                return
            }

            self.translator.translate(text: text, config: settings.translatorConfig) { [weak self] result in
                guard let self else { return }
                DispatchQueue.main.async {
                    switch result {
                    case .success(let translated):
                        self.clipboard.save()
                        self.replacer.replaceWith(translated) { [weak self] in
                            guard let self else { return }
                            self.clipboard.restore()
                            self.isTranslating = false
                            TranslationHUD.shared.show(message: "Translated")
                        }
                    case .failure(let error):
                        self.isTranslating = false
                        TranslationHUD.shared.show(message: error.localizedDescription)
                    }
                }
            }
        }
    }
}
