import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Pesan status untuk jendela Pengaturan.
@Observable
final class SettingsFeedback {
    var message: String?
}

struct SettingsView: View {
    let store = RingStore.shared
    let feedback = SettingsFeedback()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Isi Ring")
                .font(.headline)
            Text("Seret untuk mengubah urutan. Maksimal \(RingLimits.maxItems) item. Tombol sub ring di tiap baris menambah item yang muncul saat slice di-hover.")
                .font(.callout)
                .foregroundStyle(.secondary)

            List {
                ForEach(store.entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        RingEntryRow(entry: entry, onRemove: {
                            store.remove(id: entry.id)
                            feedback.message = nil
                        }) {
                            Menu {
                                addMenuItems { addChild($0, to: entry.id) }
                            } label: {
                                Image(systemName: "circle.hexagongrid")
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .fixedSize()
                            .disabled(entry.children.count >= RingLimits.maxChildren)
                            .help("Tambah ke sub ring (muncul saat di-hover)")
                        }
                        ForEach(entry.children) { child in
                            RingEntryRow(entry: child, onRemove: {
                                store.removeChild(id: child.id, from: entry.id)
                                feedback.message = nil
                            })
                            .padding(.leading, 26)
                        }
                    }
                }
                .onMove { source, destination in
                    store.move(from: source, to: destination)
                }
            }
            .frame(minHeight: 260)

            HStack {
                Menu("Tambah") {
                    addMenuItems(add)
                }
                .fixedSize()
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
        .frame(width: 420)
    }

    // MARK: Menambah

    private func add(_ entry: RingEntry) {
        switch store.add(entry) {
        case .added: feedback.message = nil
        case .full: feedback.message = "Ring penuh (maksimal \(RingLimits.maxItems) item)."
        case .duplicate: feedback.message = "Item ini sudah ada di ring."
        }
    }

    private func addChild(_ entry: RingEntry, to parentID: RingEntry.ID) {
        switch store.addChild(entry, to: parentID) {
        case .added: feedback.message = nil
        case .full: feedback.message = "Sub ring penuh (maksimal \(RingLimits.maxChildren) item)."
        case .duplicate: feedback.message = "Item ini sudah ada di sub ring."
        }
    }

    /// Isi menu tambah, dipakai untuk ring utama dan sub ring.
    @ViewBuilder
    private func addMenuItems(_ onAdd: @escaping (RingEntry) -> Void) -> some View {
        Menu("Aksi Native") {
            ForEach(NativeShortcut.builtIns) { shortcut in
                Button(shortcut.title) { onAdd(RingEntry(kind: .native(shortcut))) }
            }
            Divider()
            Button("Jalankan Shortcut…") { pickRunShortcut().map(onAdd) }
        }
        Button("Aplikasi…") { pickApp().map(onAdd) }
        Button("Folder atau File…") { pickFile().map(onAdd) }
        Button("Link Web…") { pickURL().map(onAdd) }
        Button("Hotkey…") { pickHotkey().map(onAdd) }
    }

    private func pickRunShortcut() -> RingEntry? {
        guard let name = promptText(
            title: "Jalankan Shortcut",
            info: "Masukkan nama persis dari Shortcut di aplikasi Shortcuts.",
            placeholder: "Nama Shortcut"
        ) else { return nil }
        return RingEntry(kind: .native(.runShortcut(name: name)))
    }

    private func pickApp() -> RingEntry? {
        let panel = NSOpenPanel()
        panel.title = "Pilih Aplikasi"
        panel.prompt = "Tambahkan"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let name = FileManager.default.displayName(atPath: url.path)
        return RingEntry(kind: .app(path: url.path, name: name))
    }

    private func pickFile() -> RingEntry? {
        let panel = NSOpenPanel()
        panel.title = "Pilih Folder atau File"
        panel.prompt = "Tambahkan"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return RingEntry(kind: .file(path: url.path))
    }

    private func pickURL() -> RingEntry? {
        guard let text = promptText(
            title: "Link Web",
            info: "Masukkan alamat yang akan dibuka di browser bawaan.",
            placeholder: "https://example.com"
        ) else { return nil }

        let normalized = text.contains("://") ? text : "https://\(text)"
        guard let url = URL(string: normalized), url.host?.isEmpty == false else {
            feedback.message = "Alamat tidak valid."
            return nil
        }
        return RingEntry(kind: .url(url.absoluteString))
    }

    private func pickHotkey() -> RingEntry? {
        guard let recorded = HotkeyRecorder.record() else { return nil }
        return RingEntry(kind: .hotkey(
            keyCode: recorded.keyCode,
            flags: recorded.flags,
            display: recorded.display
        ))
    }

    /// Dialog satu kolom teks. Mengembalikan nil jika dibatalkan atau kosong.
    private func promptText(title: String, info: String, placeholder: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = info
        alert.addButton(withTitle: "Tambahkan")
        alert.addButton(withTitle: "Batal")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = placeholder
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

@Observable
private final class RowState {
    var isEditing = false
}

@Observable
private final class EditorModel {
    var title: String
    var symbol: String

    init(entry: RingEntry) {
        title = entry.customTitle ?? ""
        symbol = entry.customSymbol ?? ""
    }
}

/// Satu baris entri: ikon, label, tombol ubah, dan tombol hapus.
private struct RingEntryRow<Extra: View>: View {
    let entry: RingEntry
    let onRemove: () -> Void
    @ViewBuilder let extra: Extra

    @Bindable private var state = RowState()

    init(entry: RingEntry, onRemove: @escaping () -> Void, @ViewBuilder extra: () -> Extra) {
        self.entry = entry
        self.onRemove = onRemove
        self.extra = extra()
    }

    var body: some View {
        HStack(spacing: 10) {
            icon.frame(width: 24, height: 24)
            Text(entry.title)
                .lineLimit(1)
            if let subtitle = entry.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            extra
            Button { state.isEditing = true } label: {
                Image(systemName: "pencil.circle")
            }
            .buttonStyle(.borderless)
            .help("Ubah label dan ikon")
            .popover(isPresented: $state.isEditing, arrowEdge: .trailing) {
                EntryEditor(entry: entry, isPresented: $state.isEditing)
            }
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Hapus dari ring")
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var icon: some View {
        switch entry.icon {
        case let .symbol(name):
            Image(systemName: name)
                .resizable().scaledToFit().padding(4)
                .foregroundStyle(.white)
                .background(entry.tint, in: RoundedRectangle(cornerRadius: 6))
        case let .appIcon(image):
            Image(nsImage: image).resizable()
        }
    }
}

extension RingEntryRow where Extra == EmptyView {
    init(entry: RingEntry, onRemove: @escaping () -> Void) {
        self.init(entry: entry, onRemove: onRemove) { EmptyView() }
    }
}

/// Popover untuk mengganti label dan ikon sebuah entri.
private struct EntryEditor: View {
    let entry: RingEntry
    @Binding var isPresented: Bool

    @Bindable private var model: EditorModel

    private static let presets = [
        "star.fill", "heart.fill", "bolt.fill", "flag.fill", "bookmark.fill", "folder.fill",
        "doc.fill", "globe", "envelope.fill", "calendar", "terminal.fill", "gearshape.fill",
        "music.note", "video.fill", "photo.fill", "house.fill", "cart.fill", "paintbrush.fill",
        "hammer.fill", "wand.and.stars", "magnifyingglass", "clock.fill", "moon.fill", "sun.max.fill",
    ]

    init(entry: RingEntry, isPresented: Binding<Bool>) {
        self.entry = entry
        _isPresented = isPresented
        model = EditorModel(entry: entry)
    }

    private var symbolIsValid: Bool {
        model.symbol.isEmpty || NSImage(systemSymbolName: model.symbol, accessibilityDescription: nil) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Label").font(.subheadline.weight(.semibold))
            TextField(entry.defaultTitle, text: $model.title)
                .textFieldStyle(.roundedBorder)

            Text("Ikon").font(.subheadline.weight(.semibold))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                ForEach(Self.presets, id: \.self) { name in
                    Button { model.symbol = name } label: {
                        Image(systemName: name)
                            .frame(width: 32, height: 32)
                            .background(
                                model.symbol == name ? Color.accentColor.opacity(0.3) : .clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            TextField("Nama SF Symbol (opsional)", text: $model.symbol)
                .textFieldStyle(.roundedBorder)
            if !symbolIsValid {
                Text("Simbol tidak dikenal.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Setel Ulang") {
                    model.title = ""
                    model.symbol = ""
                }
                Spacer()
                Button("Batal") { isPresented = false }
                Button("Simpan", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!symbolIsValid)
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private func save() {
        let cleanTitle = model.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSymbol = model.symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        RingStore.shared.update(
            id: entry.id,
            title: cleanTitle.isEmpty ? nil : cleanTitle,
            symbol: cleanSymbol.isEmpty ? nil : cleanSymbol
        )
        isPresented = false
    }
}
