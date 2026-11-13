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
    let feedback = SettingsFeedback()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Aplikasi di Ring")
                .font(.headline)
            Text("Screenshot selalu ada. Anda bisa menambahkan hingga \(RingAppStore.maxApps) aplikasi.")
                .font(.callout)
                .foregroundStyle(.secondary)

            List {
                ForEach(store.apps) { app in
                    HStack(spacing: 10) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text(app.name)
                        Spacer()
                        Button {
                            store.remove(app)
                            feedback.message = nil
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                        .help("Hapus dari ring")
                    }
                    .padding(.vertical, 2)
                }
            }
            .frame(minHeight: 200)

            HStack {
                Button("Tambah Aplikasi…", action: addApp)
                    .disabled(store.apps.count >= RingAppStore.maxApps)
                Spacer()
                Text("\(store.apps.count)/\(RingAppStore.maxApps)")
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
        .frame(width: 380)
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
            feedback.message = "Maksimal \(RingAppStore.maxApps) aplikasi kustom."
        }
    }
}
