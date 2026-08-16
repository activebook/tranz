import AppKit

/// Save/restore the general pasteboard so the translation cycle is non-destructive.
///
/// The fake `Cmd+C`/`Cmd+V` round-trip overwrites whatever the user had copied.
/// A full snapshot (all items, all types) is taken before the cycle and restored
/// afterwards on both success and failure.
final class ClipboardGateway {
    private var savedItems: [NSPasteboardItem] = []
    private var savedChangeCount: Int = 0

    func save() {
        let pasteboard = NSPasteboard.general
        savedChangeCount = pasteboard.changeCount
        savedItems = (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }

    func restore() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !savedItems.isEmpty {
            pasteboard.writeObjects(savedItems)
        }
    }

    func write(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    func readString() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}
