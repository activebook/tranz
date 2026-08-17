import AppKit
import SwiftUI

/// Distinct presentation states for the contextual translation HUD.
enum HUDState: Equatable {
    case idle
    case translating(targetLanguage: String)
    case success(message: String)
    case error(message: String)
    case info(message: String)
}

/// Observable view model binding state transitions with reactive SwiftUI animation flows.
final class HUDViewModel: ObservableObject {
    @Published var state: HUDState = .idle
}

/// A modern, glassmorphic capsule view displaying dynamic spinning arcs and state-morphing animations.
struct TranslationHUDView: View {
    @ObservedObject var viewModel: HUDViewModel

    var body: some View {
        HStack(spacing: 8) {
            switch viewModel.state {
            case .idle:
                EmptyView()

            case .translating(let targetLanguage):
                SpinningArc()
                Text(targetLanguage.isEmpty ? "Translating…" : "Translating to \(targetLanguage)…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)

            case .success(let message):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.green)
                    .transition(.scale.combined(with: .opacity))
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)

            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                    .transition(.scale.combined(with: .opacity))
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)

            case .info(let message):
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .transition(.scale.combined(with: .opacity))
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
        )
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 4)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.state)
    }
}

/// A continuously spinning gradient arc spinner providing clean progress feedback.
struct SpinningArc: View {
    @State private var isSpinning = false

    var body: some View {
        Circle()
            .trim(from: 0.12, to: 0.88)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [Color.accentColor.opacity(0.2), Color.accentColor]),
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
            )
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) {
                    isSpinning = true
                }
            }
    }
}

/// A floating, non-activating status capsule positioned contextually near the active input field.
final class TranslationHUD {
    static let shared = TranslationHUD()

    private var panel: NSPanel?
    private let viewModel = HUDViewModel()
    private var dismissWorkItem: DispatchWorkItem?

    private init() {}

    // MARK: - Public API

    func showTranslating(targetLanguage: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.dismissWorkItem?.cancel()
            self.viewModel.state = .translating(targetLanguage: targetLanguage)
            self.present()
        }
    }

    func showSuccess(message: String = "Translated") {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.dismissWorkItem?.cancel()
            self.viewModel.state = .success(message: message)
            self.present()
            self.scheduleDismiss(after: 0.9)
        }
    }

    func showError(message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.dismissWorkItem?.cancel()
            self.viewModel.state = .error(message: message)
            self.present()
            self.scheduleDismiss(after: 2.2)
        }
    }

    func showInfo(message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.dismissWorkItem?.cancel()
            self.viewModel.state = .info(message: message)
            self.present()
            self.scheduleDismiss(after: 2.0)
        }
    }

    /// Legacy compatibility bridge
    func show(message: String, autoDismiss: Bool = true) {
        if message.lowercased().contains("translating") {
            showTranslating(targetLanguage: "")
        } else if message.lowercased().contains("translated") {
            showSuccess(message: message)
        } else if message.lowercased().contains("error") || message.lowercased().contains("no text") {
            showError(message: message)
        } else {
            showInfo(message: message)
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            self?.dismissWorkItem?.cancel()
            self?.panel?.orderOut(nil)
            self?.viewModel.state = .idle
        }
    }

    // MARK: - Presentation Lifecycle

    private func ensurePanelCreated() -> NSPanel {
        if let existing = panel {
            return existing
        }

        let hostingView = NSHostingView(rootView: TranslationHUDView(viewModel: viewModel))
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.contentView = hostingView

        panel = p
        return p
    }

    private func present() {
        let p = ensurePanelCreated()
        guard let hostingView = p.contentView as? NSHostingView<TranslationHUDView> else { return }

        // Recalculate fitting size for dynamic content
        let fittingSize = hostingView.fittingSize
        let finalSize = NSSize(
            width: max(fittingSize.width + 8, 140),
            height: max(fittingSize.height + 4, 38)
        )
        p.setContentSize(finalSize)

        // Locate contextual anchor point near active caret or input element
        let origin = CaretLocator.shared.locateAnchor(hudSize: finalSize)
        p.setFrameOrigin(origin)

        p.orderFrontRegardless()
    }

    private func scheduleDismiss(after delay: TimeInterval) {
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                self.panel?.animator().alphaValue = 0.0
            }, completionHandler: {
                self.panel?.orderOut(nil)
                self.panel?.alphaValue = 1.0
                self.viewModel.state = .idle
            })
        }
        dismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
}
