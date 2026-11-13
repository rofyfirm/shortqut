import AppKit
import SwiftUI

/// Satu entri di ring yang bisa diurutkan, diberi label, dan diberi ikon sendiri.
struct RingEntry: Codable, Identifiable, Equatable {
    enum Kind: Codable, Equatable {
        case native(NativeShortcut)
        case app(path: String, name: String)
        case url(String)
        case file(path: String)
        case hotkey(keyCode: UInt16, flags: UInt64, display: String)
    }

    var id = UUID()
    var kind: Kind
    /// Label buatan user. Nil memakai label bawaan.
    var customTitle: String?
    /// Nama SF Symbol buatan user. Nil memakai ikon bawaan.
    var customSymbol: String?
    /// Isi sub ring yang muncul saat entri ini di-hover. Hanya satu tingkat.
    var children: [RingEntry] = []

    init(kind: Kind, customTitle: String? = nil, customSymbol: String? = nil, children: [RingEntry] = []) {
        self.kind = kind
        self.customTitle = customTitle
        self.customSymbol = customSymbol
        self.children = children
    }

    // Data lama tidak punya `children`, jadi dibaca sebagai opsional.
    private enum CodingKeys: String, CodingKey {
        case id, kind, customTitle, customSymbol, children
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decode(Kind.self, forKey: .kind)
        customTitle = try c.decodeIfPresent(String.self, forKey: .customTitle)
        customSymbol = try c.decodeIfPresent(String.self, forKey: .customSymbol)
        children = try c.decodeIfPresent([RingEntry].self, forKey: .children) ?? []
    }

    // MARK: Identitas

    /// Dua entri dengan kunci sama dianggap duplikat.
    var dedupKey: String {
        switch kind {
        case let .native(shortcut): "native:\(shortcut.id)"
        case let .app(path, _): "app:\(path)"
        case let .url(url): "url:\(url)"
        case let .file(path): "file:\(path)"
        case let .hotkey(keyCode, flags, _): "hotkey:\(keyCode):\(flags)"
        }
    }

    // MARK: Tampilan

    var defaultTitle: String {
        switch kind {
        case let .native(shortcut): shortcut.title
        case let .app(_, name): name
        case let .url(url): URL(string: url)?.host ?? url
        case let .file(path): FileManager.default.displayName(atPath: path)
        case let .hotkey(_, _, display): display
        }
    }

    var title: String {
        let trimmed = customTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? defaultTitle : trimmed
    }

    /// Keterangan jenis entri untuk daftar Pengaturan.
    var subtitle: String? {
        switch kind {
        case let .native(shortcut): shortcut.id.hasPrefix("runShortcut:") ? "Shortcut" : nil
        case .app: nil
        case let .url(url): url
        case let .file(path): (path as NSString).abbreviatingWithTildeInPath
        case .hotkey: "Hotkey"
        }
    }

    var defaultSymbol: String? {
        switch kind {
        case let .native(shortcut): shortcut.symbol
        case .app: nil
        case .url: "globe"
        case .file: nil
        case .hotkey: "command"
        }
    }

    /// Ikon efektif: simbol buatan user, simbol bawaan, atau ikon file/aplikasi asli.
    var icon: ShortcutItem.Icon {
        if let symbol = validCustomSymbol { return .symbol(symbol) }
        if let symbol = defaultSymbol { return .symbol(symbol) }
        switch kind {
        case let .app(path, _), let .file(path):
            return .appIcon(NSWorkspace.shared.icon(forFile: path))
        default:
            return .symbol("questionmark")
        }
    }

    private var validCustomSymbol: String? {
        guard let name = customSymbol?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty,
              NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
        else { return nil }
        return name
    }

    var tint: Color {
        switch kind {
        case let .native(shortcut): shortcut.tint
        case .app, .file: .accentColor
        case .url: .blue
        case .hotkey: .teal
        }
    }

    var action: ShortcutItem.Action {
        switch kind {
        case let .native(shortcut):
            shortcut.action
        case let .app(path, _), let .file(path):
            .openApp(path: path)
        case let .url(url):
            URL(string: url).map { .openURL($0) } ?? .openURL(URL(string: "about:blank")!)
        case let .hotkey(keyCode, flags, _):
            .keystroke(keyCode: CGKeyCode(keyCode), flags: CGEventFlags(rawValue: flags))
        }
    }

    var shortcutItem: ShortcutItem {
        ShortcutItem(
            title: title,
            icon: icon,
            tint: tint,
            action: action,
            children: children.map { $0.shortcutItem }
        )
    }
}

/// Batas total slice di ring.
enum RingLimits {
    static let maxItems = 12

    static var usedSlots: Int { RingStore.shared.entries.count }
    static var hasRoom: Bool { usedSlots < maxItems }

    /// Batas item per sub ring.
    static let maxChildren = 6
}

enum RingAddResult {
    case added
    case full
    case duplicate
}

/// Menyimpan semua entri ring (urutan sama dengan urutan di ring) di UserDefaults.
@Observable
final class RingStore {
    static let shared = RingStore()

    private static let defaultsKey = "ringEntries"
    // Kunci format lama, dibaca sekali untuk migrasi
    private static let legacyShortcutsKey = "ringNativeShortcuts"
    private static let legacyAppsKey = "ringApps"

    private(set) var entries: [RingEntry]

    private init() {
        entries = Self.loadSaved() ?? Self.migrateLegacy()
        save()
    }

    var items: [ShortcutItem] { entries.map(\.shortcutItem) }

    func add(_ entry: RingEntry) -> RingAddResult {
        guard !entries.contains(where: { $0.dedupKey == entry.dedupKey }) else { return .duplicate }
        guard RingLimits.hasRoom else { return .full }
        entries.append(entry)
        save()
        return .added
    }

    func remove(id: RingEntry.ID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        entries.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func update(id: RingEntry.ID, title: String?, symbol: String?) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].customTitle = title
            entries[index].customSymbol = symbol
            save()
            return
        }
        for parent in entries.indices {
            if let child = entries[parent].children.firstIndex(where: { $0.id == id }) {
                entries[parent].children[child].customTitle = title
                entries[parent].children[child].customSymbol = symbol
                save()
                return
            }
        }
    }

    func addChild(_ entry: RingEntry, to parentID: RingEntry.ID) -> RingAddResult {
        guard let parent = entries.firstIndex(where: { $0.id == parentID }) else { return .full }
        let siblings = entries[parent].children
        guard !siblings.contains(where: { $0.dedupKey == entry.dedupKey }) else { return .duplicate }
        guard siblings.count < RingLimits.maxChildren else { return .full }
        // Sub ring hanya satu tingkat
        var child = entry
        child.children = []
        entries[parent].children.append(child)
        save()
        return .added
    }

    func removeChild(id: RingEntry.ID, from parentID: RingEntry.ID) {
        guard let parent = entries.firstIndex(where: { $0.id == parentID }) else { return }
        entries[parent].children.removeAll { $0.id == id }
        save()
    }

    // MARK: Private

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    private static func loadSaved() -> [RingEntry]? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode([RingEntry].self, from: data)
    }

    /// Menggabungkan daftar lama (aksi native lalu aplikasi) menjadi satu daftar.
    private static func migrateLegacy() -> [RingEntry] {
        let defaults = UserDefaults.standard

        let shortcuts: [NativeShortcut] = defaults.data(forKey: legacyShortcutsKey)
            .flatMap { try? JSONDecoder().decode([NativeShortcut].self, from: $0) }
            ?? [.screenshot]

        let apps: [RingApp] = defaults.data(forKey: legacyAppsKey)
            .flatMap { try? JSONDecoder().decode([RingApp].self, from: $0) }
            ?? defaultApps()

        let native = shortcuts.map { RingEntry(kind: .native($0)) }
        let appEntries = apps.map { RingEntry(kind: .app(path: $0.path, name: $0.name)) }
        return Array((native + appEntries).prefix(RingLimits.maxItems))
    }

    /// Finder dan Terminal dipakai saat pertama kali dijalankan.
    private static func defaultApps() -> [RingApp] {
        ["com.apple.finder", "com.apple.Terminal"].compactMap { bundleID in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                return nil
            }
            return RingApp(
                name: FileManager.default.displayName(atPath: url.path),
                path: url.path
            )
        }
    }
}
