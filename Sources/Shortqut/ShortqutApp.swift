import SwiftUI

@main
struct ShortqutApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Shortqut", systemImage: "circle.grid.cross") {
            MenuContent(ring: appDelegate.ringController)
        }

        Window("Pengaturan Shortqut", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}

struct MenuContent: View {
    @Environment(\.openWindow) private var openWindow
    let ring: RingController

    var body: some View {
        Button("Tampilkan Shortqut") {
            ring.showAtCursor()
        }

        Button("Pengaturan…") {
            openWindow(id: "settings")
            NSApp.activate()
        }
        .keyboardShortcut(",")

        Button(Permissions.hasAccessibility
               ? "Izin Aksesibilitas: Aktif"
               : "Berikan Izin Aksesibilitas…") {
            Permissions.requestAccessibility()
        }

        Divider()

        Toggle("Jalankan Saat Login", isOn: Binding(
            get: { LaunchAtLogin.isEnabled },
            set: { enabled in
                if LaunchAtLogin.setEnabled(enabled), enabled, LaunchAtLogin.needsApproval {
                    LaunchAtLogin.openLoginItemsSettings()
                }
            }
        ))

        Divider()

        Button("Keluar Shortqut") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let ringController = RingController()
    private let trackpad = TrackpadGestureMonitor()
    private let commandTap = CommandDoubleTapMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Tanpa ikon di Dock, hanya muncul di menu bar
        NSApp.setActivationPolicy(.accessory)

        trackpad.onFourFingerTap = { [weak self] in
            self?.ringController.toggleAtCursor()
        }
        trackpad.start()

        commandTap.onDoubleTap = { [weak self] in
            self?.ringController.toggleAtCursor()
        }
        commandTap.start()
    }
}
