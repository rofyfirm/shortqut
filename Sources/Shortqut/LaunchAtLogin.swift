import ServiceManagement

/// Menjalankan Shortqut otomatis saat user login (setelah Mac menyala).
/// Memakai SMAppService, yang tersedia sejak macOS 13.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Mengaktifkan atau menonaktifkan. Mengembalikan false jika gagal.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("Shortqut: gagal mengubah jalankan saat login: \(error.localizedDescription)")
            return false
        }
    }

    /// Dibutuhkan macOS jika user perlu menyetujui item login secara manual.
    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
