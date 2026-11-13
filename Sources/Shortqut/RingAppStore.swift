import AppKit
import SwiftUI

/// Aplikasi yang dipilih user untuk ditampilkan di ring.
struct RingApp: Codable, Identifiable, Equatable {
    var id: String { path }
    let name: String
    let path: String
}

/// Menyimpan daftar aplikasi kustom di UserDefaults.
@Observable
final class RingAppStore {
    static let shared = RingAppStore()
    private static let defaultsKey = "ringApps"

    private(set) var apps: [RingApp]

    private init() {
        apps = Self.loadSavedApps() ?? Self.defaultApps()
    }

    /// Menambahkan aplikasi. Mengembalikan false jika sudah penuh atau sudah ada.
    @discardableResult
    func add(appURL: URL) -> Bool {
        guard RingLimits.hasRoom,
              !apps.contains(where: { $0.path == appURL.path })
        else { return false }

        apps.append(RingApp(
            name: FileManager.default.displayName(atPath: appURL.path),
            path: appURL.path
        ))
        save()
        return true
    }

    func remove(_ app: RingApp) {
        apps.removeAll { $0.path == app.path }
        save()
    }

    // MARK: Private

    private func save() {
        guard let data = try? JSONEncoder().encode(apps) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    private static func loadSavedApps() -> [RingApp]? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode([RingApp].self, from: data)
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
