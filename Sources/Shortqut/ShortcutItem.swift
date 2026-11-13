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
    }

    let id = UUID()
    let title: String
    let icon: Icon
    let tint: Color
    let action: Action
}

extension ShortcutItem {
    /// Aksi bawaan yang selalu ada di ring.
    static let screenshot = ShortcutItem(
        title: "Screenshot",
        icon: .symbol("camera.viewfinder"),
        tint: .pink,
        action: .keystroke(keyCode: KeyCode.four, flags: [.maskCommand, .maskShift])
    )

    /// Susun slice ring: Screenshot diikuti aplikasi pilihan user.
    static func ring(from apps: [RingApp]) -> [ShortcutItem] {
        let appItems = apps.map { app in
            ShortcutItem(
                title: app.name,
                icon: .appIcon(NSWorkspace.shared.icon(forFile: app.path)),
                tint: .accentColor,
                action: .openApp(path: app.path)
            )
        }
        return [screenshot] + appItems
    }
}

/// Virtual key code ANSI untuk macOS.
enum KeyCode {
    static let four: CGKeyCode = 0x15
}

/// Menjalankan aksi dari slice yang dipilih.
enum ActionRunner {
    static func run(_ item: ShortcutItem) {
        switch item.action {
        case let .keystroke(keyCode, flags):
            postKeystroke(keyCode, flags: flags)

        case let .openApp(path):
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
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
