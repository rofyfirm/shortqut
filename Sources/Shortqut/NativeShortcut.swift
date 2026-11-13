import AppKit
import SwiftUI

/// Aksi native yang bisa dipasang di ring. `runShortcut` menjalankan Shortcut buatan user di Shortcuts.app.
enum NativeShortcut: Codable, Hashable, Identifiable {
    case screenshot
    case missionControl
    case lockScreen
    case screenRecording
    case playPause
    case runShortcut(name: String)

    /// Aksi bawaan yang bisa dipilih dari menu tambah (tanpa `runShortcut`, yang butuh nama).
    static let builtIns: [NativeShortcut] = [
        .screenshot, .missionControl, .lockScreen, .screenRecording, .playPause,
    ]

    var id: String {
        switch self {
        case .screenshot: "screenshot"
        case .missionControl: "missionControl"
        case .lockScreen: "lockScreen"
        case .screenRecording: "screenRecording"
        case .playPause: "playPause"
        case let .runShortcut(name): "runShortcut:\(name)"
        }
    }

    var title: String {
        switch self {
        case .screenshot: "Screenshot"
        case .missionControl: "Mission Control"
        case .lockScreen: String(localized: "Lock Screen")
        case .screenRecording: String(localized: "Record Screen")
        case .playPause: String(localized: "Play/Pause")
        case let .runShortcut(name): name
        }
    }

    var symbol: String {
        switch self {
        case .screenshot: "camera.viewfinder"
        case .missionControl: "rectangle.3.group"
        case .lockScreen: "lock.fill"
        case .screenRecording: "record.circle"
        case .playPause: "playpause.fill"
        case .runShortcut: "bolt.fill"
        }
    }

    var tint: Color {
        switch self {
        case .screenshot: .pink
        case .missionControl: .indigo
        case .lockScreen: .gray
        case .screenRecording: .red
        case .playPause: .green
        case .runShortcut: .orange
        }
    }

    var action: ShortcutItem.Action {
        switch self {
        case .screenshot:
            .keystroke(keyCode: KeyCode.four, flags: [.maskCommand, .maskShift])
        case .missionControl:
            .openApp(path: "/System/Applications/Mission Control.app")
        case .lockScreen:
            .keystroke(keyCode: KeyCode.q, flags: [.maskCommand, .maskControl])
        case .screenRecording:
            .keystroke(keyCode: KeyCode.five, flags: [.maskCommand, .maskShift])
        case .playPause:
            .mediaKey(MediaKey.playPause)
        case let .runShortcut(name):
            .runShortcut(name: name)
        }
    }
}
