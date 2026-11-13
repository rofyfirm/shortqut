import Foundation

/// Format lama untuk aplikasi di ring. Hanya dipakai saat migrasi ke `RingStore`.
struct RingApp: Codable, Identifiable, Equatable {
    var id: String { path }
    let name: String
    let path: String
}
