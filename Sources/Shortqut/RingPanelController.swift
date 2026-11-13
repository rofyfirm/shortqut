import AppKit
import SwiftUI

/// State ring yang dibagikan antara controller dan tampilan SwiftUI.
@Observable
final class RingModel {
    var items: [ShortcutItem]
    var isOpen = false
    var hovered: Int?
    var onSelect: ((ShortcutItem?) -> Void)?

    init(items: [ShortcutItem]) {
        self.items = items
    }

    func activate() {
        onSelect?(hovered.map { items[$0] })
    }
}

/// Panel tanpa bingkai yang tidak mencuri fokus dari app yang sedang dipakai.
final class RingPanel: NSPanel {
    init(size: CGSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Menampilkan dan menyembunyikan ring tepat di posisi kursor.
final class RingController {
    static let size = CGSize(width: 300, height: 300)

    let model = RingModel(items: ShortcutItem.ring(from: RingAppStore.shared.apps))
    private var panel: RingPanel?
    private var clickMonitor: Any?

    init() {
        model.onSelect = { [weak self] item in
            self?.hide()
            guard let item else { return }
            // Beri waktu agar app sebelumnya kembali fokus sebelum aksi dikirim
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                ActionRunner.run(item)
            }
        }
    }

    func toggleAtCursor() {
        if model.isOpen {
            hide()
        } else {
            showAtCursor()
        }
    }

    func showAtCursor() {
        let panel = self.panel ?? makePanel()
        self.panel = panel

        // Susun ulang slice agar selalu sesuai daftar aplikasi terbaru
        model.items = ShortcutItem.ring(from: RingAppStore.shared.apps)
        panel.setFrameOrigin(originNearCursor())
        model.hovered = nil
        model.isOpen = false
        panel.orderFrontRegardless()

        // State diubah di run loop berikutnya agar SwiftUI sempat merender keadaan awal,
        // sehingga animasi masuk berjalan.
        DispatchQueue.main.async { [weak self] in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                self?.model.isOpen = true
            }
        }

        installClickMonitor()
    }

    func hide() {
        removeClickMonitor()
        withAnimation(.easeIn(duration: 0.12)) {
            model.isOpen = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in
            // Jangan sembunyikan jika sudah dibuka lagi dalam jeda ini
            guard let self, !self.model.isOpen else { return }
            self.panel?.orderOut(nil)
        }
    }

    // MARK: Private

    private func makePanel() -> RingPanel {
        let panel = RingPanel(size: Self.size)
        panel.contentView = NSHostingView(rootView: RingView(model: model))
        return panel
    }

    /// Pusat ring berada di kursor, tetapi tetap dijaga agar tidak keluar layar.
    private func originNearCursor() -> NSPoint {
        let mouse = NSEvent.mouseLocation
        var origin = NSPoint(
            x: mouse.x - Self.size.width / 2,
            y: mouse.y - Self.size.height / 2
        )
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) {
            let area = screen.visibleFrame.insetBy(dx: 8, dy: 8)
            origin.x = min(max(origin.x, area.minX), area.maxX - Self.size.width)
            origin.y = min(max(origin.y, area.minY), area.maxY - Self.size.height)
        }
        return origin
    }

    /// Klik di luar ring menutup ring tanpa menjalankan aksi.
    private func installClickMonitor() {
        removeClickMonitor()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            guard let self, let panel = self.panel else { return }
            if !panel.frame.contains(NSEvent.mouseLocation) {
                self.hide()
            }
        }
    }

    private func removeClickMonitor() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
    }
}
