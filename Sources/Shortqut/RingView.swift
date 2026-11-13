import SwiftUI

/// Geometri ring. Sudut diukur searah jarum jam dari atas (0° = atas).
struct RingGeometry {
    let center: CGPoint
    let inner: CGFloat
    let outer: CGFloat
    let count: Int

    /// Lebar celah antar slice dalam poin (sama di radius dalam dan luar)
    private static let gapPoints: CGFloat = 6

    var step: Double { 360 / Double(max(count, 1)) }

    func point(degrees: Double, radius: CGFloat) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(
            x: center.x + radius * CGFloat(sin(radians)),
            y: center.y - radius * CGFloat(cos(radians))
        )
    }

    /// Posisi ikon di tengah sebuah slice, digeser sejauh `lift` ke arah luar.
    func iconAnchor(index: Int, lift: CGFloat) -> CGPoint {
        point(degrees: Double(index) * step, radius: (inner + outer) / 2 + lift)
    }

    /// Mengembalikan index slice di bawah kursor, atau nil jika di area kosong.
    func index(at location: CGPoint) -> Int? {
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = hypot(dx, dy)
        guard distance >= inner, distance <= outer + 12, count > 0 else { return nil }

        var degrees = atan2(Double(dx), Double(-dy)) * 180 / .pi
        if degrees < 0 { degrees += 360 }

        let shifted = (degrees + step / 2).truncatingRemainder(dividingBy: 360)
        return min(Int(shifted / step), count - 1)
    }

    /// Satu slice berbentuk juring. Kedua tepi radialnya sejajar sehingga celah selalu rata.
    func segmentPath(index: Int) -> Path {
        let boundaryStart = Double(index) * step - step / 2
        let boundaryEnd = boundaryStart + step
        let halfGap = Self.gapPoints / 2
        let steps = 24

        // Sudut tepi slice pada radius tertentu, digeser agar jaraknya dari garis radial = halfGap
        func edgeAngle(_ boundary: Double, radius: CGFloat, isStart: Bool) -> Double {
            let offset = asin(Double(halfGap / radius)) * 180 / .pi
            return isStart ? boundary + offset : boundary - offset
        }

        var path = Path()
        let outerStart = edgeAngle(boundaryStart, radius: outer, isStart: true)
        let outerEnd = edgeAngle(boundaryEnd, radius: outer, isStart: false)
        for s in 0...steps {
            let angle = outerStart + (outerEnd - outerStart) * Double(s) / Double(steps)
            let point = point(degrees: angle, radius: outer)
            if s == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        let innerStart = edgeAngle(boundaryStart, radius: inner, isStart: true)
        let innerEnd = edgeAngle(boundaryEnd, radius: inner, isStart: false)
        for s in 0...steps {
            let angle = innerEnd - (innerEnd - innerStart) * Double(s) / Double(steps)
            path.addLine(to: point(degrees: angle, radius: inner))
        }

        path.closeSubpath()
        return path
    }
}

struct SegmentShape: Shape {
    let geometry: RingGeometry
    let index: Int

    func path(in rect: CGRect) -> Path {
        geometry.segmentPath(index: index)
    }
}

/// Ikon slice: SF Symbol untuk aksi bawaan, ikon aplikasi asli untuk aplikasi kustom.
struct SliceIcon: View {
    let icon: ShortcutItem.Icon
    let isHovered: Bool

    var body: some View {
        switch icon {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isHovered ? Color.white : Color.primary)
        case .appIcon(let image):
            Image(nsImage: image)
                .resizable()
                .frame(width: 30, height: 30)
        }
    }
}

struct RingView: View {
    let model: RingModel

    private let canvas: CGFloat = 300
    private let inner: CGFloat = 50
    private let outer: CGFloat = 124
    /// Warna isi slice dan border dibuat sama
    private let segmentColor = Color.primary.opacity(0.22)

    var body: some View {
        let geometry = RingGeometry(
            center: CGPoint(x: canvas / 2, y: canvas / 2),
            inner: inner,
            outer: outer,
            count: model.items.count
        )
        let hovered = model.hovered.map { model.items[$0] }

        ZStack {
            // Piringan latar memakai material native macOS
            Circle()
                .fill(.regularMaterial)
                .frame(width: (outer + 8) * 2, height: (outer + 8) * 2)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
                .position(geometry.center)

            ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                let isHovered = model.hovered == index
                let lift: CGFloat = isHovered ? 6 : 0
                let anchor = geometry.iconAnchor(index: index, lift: lift)
                let liftOffset = CGSize(
                    width: anchor.x - geometry.iconAnchor(index: index, lift: 0).x,
                    height: anchor.y - geometry.iconAnchor(index: index, lift: 0).y
                )

                SegmentShape(geometry: geometry, index: index)
                    .fill(isHovered ? item.tint.opacity(0.9) : segmentColor)
                    .overlay(
                        SegmentShape(geometry: geometry, index: index)
                            .stroke(segmentColor, lineWidth: 1)
                    )
                    .offset(liftOffset)

                SliceIcon(icon: item.icon, isHovered: isHovered)
                    .scaleEffect(isHovered ? 1.12 : 1)
                    .position(geometry.iconAnchor(index: index, lift: 0))
                    .offset(liftOffset)
            }

            // Pusat ring: ikon slice yang disorot, atau logo Shortqut jika tidak ada
            Circle()
                .fill(.thinMaterial)
                .frame(width: (inner - 6) * 2, height: (inner - 6) * 2)
                .position(geometry.center)

            Group {
                if let hovered {
                    SliceIcon(icon: hovered.icon, isHovered: false)
                } else {
                    Image(systemName: "circle.grid.cross")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .id(hovered?.id)
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
            .position(geometry.center)
        }
        .frame(width: canvas, height: canvas)
        .contentShape(Rectangle())
        .scaleEffect(model.isOpen ? 1 : 0.6)
        .opacity(model.isOpen ? 1 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: model.hovered)
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                model.hovered = geometry.index(at: location)
            case .ended:
                model.hovered = nil
            }
        }
        .onTapGesture {
            model.activate()
        }
    }
}
