import AppKit
import SwiftUI

/// Satu slice pada ring.
struct ShortcutItem: Identifiable {
    enum Icon {
        case symbol(String)
        case appIcon(NSImage)
    }

    enum Action {
        case keystroke(keyCode: CGKeyCode, flags: CGEventFlags)
        case openApp(path: String)
        case mediaKey(Int32)
        case runShortcut(name: String)
        case openURL(URL)
    }

    let id = UUID()
    let title: String
    let icon: Icon
    let tint: Color
    let action: Action
    /// Item sub ring yang muncul saat slice ini di-hover.
    var children: [ShortcutItem] = []
}

extension ShortcutItem {
    /// Susun slice ring dari entri user, sesuai urutannya.
    static func ring(entries: [RingEntry]) -> [ShortcutItem] {
        entries.map(\.shortcutItem)
    }
}

/// Virtual key code ANSI untuk macOS.
enum KeyCode {
    static let four: CGKeyCode = 0x15
    static let five: CGKeyCode = 0x17
    static let q: CGKeyCode = 0x0C
}

/// Kode media key (NX_KEYTYPE_*).
enum MediaKey {
    static let playPause: Int32 = 16
}

/// Menjalankan aksi dari slice yang dipilih.
enum ActionRunner {
    static func run(_ item: ShortcutItem) {
        switch item.action {
        case let .keystroke(keyCode, flags):
            postKeystroke(keyCode, flags: flags)

        case let .openApp(path):
            NSWorkspace.shared.open(URL(fileURLWithPath: path))

        case let .mediaKey(key):
            postMediaKey(key)

        case let .runShortcut(name):
            runShortcut(named: name)

        case let .openURL(url):
            NSWorkspace.shared.open(url)
        }
    }

    /// Menjalankan Shortcut lewat CLI `shortcuts` bawaan macOS.
    private static func runShortcut(named name: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        try? process.run()
    }

    private static func postMediaKey(_ key: Int32) {
        guard Permissions.hasAccessibility else {
            Permissions.requestAccessibility()
            return
        }

        for keyDown in [true, false] {
            let state: Int = keyDown ? 0xA : 0xB
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: (Int(key) << 16) | (state << 8),
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }

    private static func postKeystroke(_ keyCode: CGKeyCode, flags: CGEventFlags) {
        // Mengirim tombol membutuhkan izin Aksesibilitas
        guard Permissions.hasAccessibility else {
            Permissions.requestAccessibility()
            return
        }

        let source = CGEventSource(stateID: .combinedSessionState)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
    }
}
