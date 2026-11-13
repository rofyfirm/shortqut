import AppKit

/// Mendeteksi tombol Command yang ditekan dua kali (tanpa tombol lain di antaranya).
final class CommandDoubleTapMonitor {
    var onDoubleTap: (() -> Void)?

    /// Jeda maksimal antara lepas tekanan pertama dan tekan kedua
    private let maxInterval: TimeInterval = 0.35

    private var monitors: [Any] = []
    private var commandIsDown = false
    /// Tekanan Command saat ini tidak bercampur dengan tombol lain
    private var pressIsClean = false
    /// Waktu lepas dari tekanan Command yang bersih (0 = tidak ada)
    private var lastCleanRelease: TimeInterval = 0

    func start() {
        let flags = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlags(event)
        }
        let cancel = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.cancelPress()
        }
        let localFlags = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlags(event)
            return event
        }

        monitors = [flags, cancel, localFlags].compactMap { $0 }
    }

    // MARK: Private

    private func handleFlags(_ event: NSEvent) {
        let now = event.timestamp
        let isDown = event.modifierFlags.contains(.command)
        let otherModifiers = event.modifierFlags.intersection([.shift, .option, .control, .function])

        // Tombol modifier lain ikut ditekan: bukan double tap Command
        if !otherModifiers.isEmpty {
            cancelPress()
            return
        }

        if isDown && !commandIsDown {
            // Tekan pertama atau kedua. Kedua jika tekanan sebelumnya baru saja dilepas.
            commandIsDown = true
            pressIsClean = true
            let isSecondPress = lastCleanRelease > 0 && now - lastCleanRelease <= maxInterval
            pendingDoubleTap = isSecondPress
        } else if !isDown && commandIsDown {
            commandIsDown = false
            if pressIsClean && pendingDoubleTap {
                lastCleanRelease = 0
                pendingDoubleTap = false
                DispatchQueue.main.async { [weak self] in
                    self?.onDoubleTap?()
                }
            } else if pressIsClean {
                lastCleanRelease = now
            } else {
                lastCleanRelease = 0
            }
            pressIsClean = false
        }
    }

    private var pendingDoubleTap = false

    /// Tombol lain ditekan saat Command ditahan (misalnya Cmd+C): batalkan deteksi
    private func cancelPress() {
        guard commandIsDown else { return }
        pressIsClean = false
        pendingDoubleTap = false
        lastCleanRelease = 0
    }
}
