import AppKit
import ApplicationServices

/// Determines the contextual screen coordinates of the active text caret or focused input field
/// across arbitrary macOS applications to position the translation HUD directly where the user is looking.
final class CaretLocator {
    static let shared = CaretLocator()

    private init() {}

    /// Computes the recommended origin in Cocoa screen coordinates for a HUD of given size.
    func locateAnchor(hudSize: NSSize) -> NSPoint {
        let activeScreen = currentScreen()
        let visibleFrame = activeScreen.visibleFrame
        let primaryHeight = NSScreen.screens.first?.frame.height ?? activeScreen.frame.height

        // 1. Attempt to resolve focused element / caret bounds via Accessibility API
        if let targetRect = findFocusedTargetRect(primaryScreenHeight: primaryHeight) {
            return computePosition(for: targetRect, hudSize: hudSize, visibleFrame: visibleFrame)
        }

        // 2. Fallback: Position relative to current mouse cursor if within visible screen bounds
        let mouseLoc = NSEvent.mouseLocation
        if visibleFrame.contains(mouseLoc) {
            let x = clamp(mouseLoc.x - hudSize.width / 2, min: visibleFrame.minX + 16, max: visibleFrame.maxX - hudSize.width - 16)
            let y = clamp(mouseLoc.y - hudSize.height - 24, min: visibleFrame.minY + 16, max: visibleFrame.maxY - hudSize.height - 16)
            return NSPoint(x: x, y: y)
        }

        // 3. Ultimate Fallback: Center-floating capsule in the upper-middle quadrant of the active screen
        let x = visibleFrame.midX - hudSize.width / 2
        let y = visibleFrame.midY + 80
        return NSPoint(x: x, y: y)
    }

    // MARK: - Accessibility Resolution

    private func findFocusedTargetRect(primaryScreenHeight: CGFloat) -> NSRect? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedAppValue: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppValue) == .success,
              let focusedApp = focusedAppValue else {
            return nil
        }
        let appElement = focusedApp as! AXUIElement

        var focusedElementValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElementValue) == .success,
              let focusedElement = focusedElementValue else {
            return nil
        }
        let element = focusedElement as! AXUIElement

        // 1. Primary: Query the input control's bounding frame (position & size)
        var posValue: AnyObject?
        var sizeValue: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue) == .success,
           AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
           let posVal = posValue,
           let sizeVal = sizeValue,
           CFGetTypeID(posVal) == AXValueGetTypeID(),
           CFGetTypeID(sizeVal) == AXValueGetTypeID() {
            var pt = CGPoint.zero
            var sz = CGSize.zero
            if AXValueGetValue(posVal as! AXValue, .cgPoint, &pt),
               AXValueGetValue(sizeVal as! AXValue, .cgSize, &sz),
               sz.width > 0, sz.height > 0 {
                let cocoaY = primaryScreenHeight - pt.y - sz.height
                return NSRect(x: pt.x, y: cocoaY, width: sz.width, height: sz.height)
            }
        }

        // 2. Secondary: Fallback to exact selection / caret range bounds if element box is unavailable
        var selectedRangeValue: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue) == .success,
           let rangeValue = selectedRangeValue,
           CFGetTypeID(rangeValue) == AXValueGetTypeID() {
            let axRange = rangeValue as! AXValue
            var boundsValue: AnyObject?
            if AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, axRange, &boundsValue) == .success,
               let boundsVal = boundsValue,
               CFGetTypeID(boundsVal) == AXValueGetTypeID() {
                var cgRect = CGRect.zero
                if AXValueGetValue(boundsVal as! AXValue, .cgRect, &cgRect), cgRect.width > 0, cgRect.height > 0 {
                    let cocoaY = primaryScreenHeight - cgRect.origin.y - cgRect.size.height
                    return NSRect(x: cgRect.origin.x, y: cocoaY, width: cgRect.size.width, height: cgRect.size.height)
                }
            }
        }

        return nil
    }

    // MARK: - Positioning Mathematics

    private func computePosition(for targetRect: NSRect, hudSize: NSSize, visibleFrame: NSRect) -> NSPoint {
        // Horizontally: Vertically align with the left side (leading edge) of the input area
        var x = targetRect.minX

        // Vertically: Place directly on the next line beneath the input field with a 6px margin
        var y = targetRect.minY - hudSize.height - 6

        // If placing below goes off the bottom of the screen, flip directly above the input field
        if y < visibleFrame.minY + 12 {
            y = targetRect.maxY + 6
        }

        // Clamp inside visible bounds so it never clips off the screen
        x = clamp(x, min: visibleFrame.minX + 16, max: visibleFrame.maxX - hudSize.width - 16)
        y = clamp(y, min: visibleFrame.minY + 16, max: visibleFrame.maxY - hudSize.height - 16)

        return NSPoint(x: x, y: y)
    }

    private func currentScreen() -> NSScreen {
        let mouseLoc = NSEvent.mouseLocation
        if let screenWithMouse = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) {
            return screenWithMouse
        }
        return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
    }

    private func clamp(_ val: CGFloat, min minVal: CGFloat, max maxVal: CGFloat) -> CGFloat {
        if maxVal < minVal { return minVal }
        return Swift.max(minVal, Swift.min(maxVal, val))
    }
}
