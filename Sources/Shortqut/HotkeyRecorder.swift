import AppKit

/// Merekam satu kombinasi tombol lewat dialog modal.
enum HotkeyRecorder {
    struct Recorded {
        let keyCode: UInt16
        let flags: UInt64
        let display: String
    }

    private final class Box {
        var recorded: Recorded?
    }

    /// Menampilkan dialog dan menunggu user menekan kombinasi tombol. Nil jika dibatalkan.
    static func record() -> Recorded? {
        let alert = NSAlert()
        alert.messageText = String(localized: "Record Hotkey")
        alert.informativeText = String(localized: "Press the key combination to send when this item is selected.")
        alert.addButton(withTitle: String(localized: "Add"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.buttons[0].isEnabled = false

        let label = NSTextField(labelWithString: String(localized: "Waiting for keys…"))
        label.alignment = .center
        label.font = .monospacedSystemFont(ofSize: 22, weight: .medium)
        label.frame = NSRect(x: 0, y: 0, width: 260, height: 36)
        alert.accessoryView = label

        let box = Box()
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let recorded = Recorded(
                keyCode: event.keyCode,
                flags: cgFlags(from: event.modifierFlags).rawValue,
                display: display(for: event)
            )
            box.recorded = recorded
            label.stringValue = recorded.display
            alert.buttons[0].isEnabled = true
            return nil // Tombol tidak diteruskan ke dialog
        }
        defer { if let monitor { NSEvent.removeMonitor(monitor) } }

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return box.recorded
    }

    private static func cgFlags(from flags: NSEvent.ModifierFlags) -> CGEventFlags {
        var result: CGEventFlags = []
        if flags.contains(.command) { result.insert(.maskCommand) }
        if flags.contains(.shift) { result.insert(.maskShift) }
        if flags.contains(.option) { result.insert(.maskAlternate) }
        if flags.contains(.control) { result.insert(.maskControl) }
        return result
    }

    private static let keyNames: [UInt16: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 117: "⌦",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    private static func display(for event: NSEvent) -> String {
        let flags = event.modifierFlags
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        text += keyNames[event.keyCode]
            ?? event.charactersIgnoringModifiers?.uppercased()
            ?? "?"
        return text
    }
}
