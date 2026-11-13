import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Pesan status untuk jendela Pengaturan.
@Observable
final class SettingsFeedback {
    var message: String?
}

struct SettingsView: View {
    let store = RingAppStore.shared
    let shortcutStore = NativeShortcutStore.shared
    let feedback = SettingsFeedback()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Isi Ring")
                .font(.headline)
            Text("Pilih aksi native dan aplikasi untuk ring. Maksimal \(RingLimits.maxItems) item.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("Aksi Native")
                .font(.subheadline.weight(.semibold))
            List {
                ForEach(shortcutStore.shortcuts) { shortcut in
                    row(
                        icon: Image(systemName: shortcut.symbol)
                            .resizable().scaledToFit().padding(4)
                            .foregroundStyle(.white)
                            .background(shortcut.tint, in: RoundedRectangle(cornerRadius: 6)),
                        title: shortcut.title,
                        subtitle: shortcut.id.hasPrefix("runShortcut:") ? "Shortcut" : nil
                    ) {
                        shortcutStore.remove(shortcut)
                        feedback.message = nil
                    }
                }
            }
            .frame(minHeight: 120)

            HStack {
                Menu("Tambah Aksi") {
                    ForEach(NativeShortcut.builtIns.filter { !shortcutStore.shortcuts.contains($0) }) { shortcut in
                        Button(shortcut.title) { addShortcut(shortcut) }
                    }
                    Divider()
                    Button("Jalankan Shortcut…", action: addRunShortcut)
                }
                .fixedSize()
                .disabled(!RingLimits.hasRoom)
                Spacer()
            }

            Text("Aplikasi")
                .font(.subheadline.weight(.semibold))
            List {
                ForEach(store.apps) { app in
                    row(
                        icon: Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                            .resizable(),
                        title: app.name,
                        subtitle: nil
                    ) {
                        store.remove(app)
                        feedback.message = nil
                    }
                }
            }
            .frame(minHeight: 120)

            HStack {
                Button("Tambah Aplikasi…", action: addApp)
                    .disabled(!RingLimits.hasRoom)
                Spacer()
                Text("\(RingLimits.usedSlots)/\(RingLimits.maxItems)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            if let message = feedback.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private func row(
        icon: some View,
        title: String,
        subtitle: String?,
        onRemove: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            icon.frame(width: 24, height: 24)
            Text(title)
            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Hapus dari ring")
        }
        .padding(.vertical, 2)
    }

    private func addShortcut(_ shortcut: NativeShortcut) {
        if shortcutStore.add(shortcut) {
            feedback.message = nil
        } else {
            feedback.message = "Ring penuh (maksimal \(RingLimits.maxItems) item)."
        }
    }

    private func addRunShortcut() {
        let alert = NSAlert()
        alert.messageText = "Jalankan Shortcut"
        alert.informativeText = "Masukkan nama persis dari Shortcut di aplikasi Shortcuts."
        alert.addButton(withTitle: "Tambahkan")
        alert.addButton(withTitle: "Batal")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = "Nama Shortcut"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if shortcutStore.shortcuts.contains(.runShortcut(name: name)) {
            feedback.message = "Shortcut ini sudah ada di ring."
        } else {
            addShortcut(.runShortcut(name: name))
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.title = "Pilih Aplikasi"
        panel.prompt = "Tambahkan"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        if store.apps.contains(where: { $0.path == url.path }) {
            feedback.message = "Aplikasi ini sudah ada di ring."
        } else if store.add(appURL: url) {
            feedback.message = nil
        } else {
            feedback.message = "Ring penuh (maksimal \(RingLimits.maxItems) item)."
        }
    }
}
