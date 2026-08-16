import AppKit

// Menu-bar app entry point.
//
// The app runs as an accessory (no Dock icon — enforced both here via
// `setActivationPolicy(.accessory)` and in the bundle's Info.plist via
// `LSUIElement = true`). The delegate is retained for the lifetime of `run()`,
// which blocks until termination, so the local `delegate` stays alive.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
