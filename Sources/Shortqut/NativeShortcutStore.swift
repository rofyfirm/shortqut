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
        case .lockScreen: "Kunci Layar"
        case .screenRecording: "Rekam Layar"
        case .playPause: "Putar/Jeda"
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

/// Batas total slice di ring (aksi native + aplikasi).
enum RingLimits {
    static let maxItems = 12

    static var usedSlots: Int {
        NativeShortcutStore.shared.shortcuts.count + RingAppStore.shared.apps.count
    }

    static var hasRoom: Bool { usedSlots < maxItems }
}

/// Menyimpan daftar aksi native pilihan user di UserDefaults.
@Observable
final class NativeShortcutStore {
    static let shared = NativeShortcutStore()

    private static let defaultsKey = "ringNativeShortcuts"

    private(set) var shortcuts: [NativeShortcut]

    private init() {
        shortcuts = Self.loadSaved() ?? [.screenshot]
    }

    /// Menambahkan aksi. Mengembalikan false jika ring penuh atau aksi sudah ada.
    @discardableResult
    func add(_ shortcut: NativeShortcut) -> Bool {
        guard RingLimits.hasRoom, !shortcuts.contains(shortcut) else { return false }
        shortcuts.append(shortcut)
        save()
        return true
    }

    func remove(_ shortcut: NativeShortcut) {
        shortcuts.removeAll { $0 == shortcut }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(shortcuts) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    private static func loadSaved() -> [NativeShortcut]? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode([NativeShortcut].self, from: data)
    }
}
