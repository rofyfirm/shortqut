import ApplicationServices

enum Permissions {
    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    /// Menampilkan dialog izin Aksesibilitas macOS jika belum diberikan.
    static func requestAccessibility() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }
}
