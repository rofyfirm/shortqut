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

    // MARK: Sub ring

    /// Sub ring berupa pita juring di luar ring utama
    static let subInner: CGFloat = 130
    static let subOuter: CGFloat = 184
    /// Lebar sudut tiap potongan sub ring
    static let subSpan: Double = 36

    /// Sudut tengah potongan sub ring ke-`sub`, disebar mengelilingi arah slice induk.
    func subAngle(parent: Int, sub: Int, count subCount: Int) -> Double {
        Double(parent) * step + (Double(sub) - Double(subCount - 1) / 2) * Self.subSpan
    }

    func subIconAnchor(parent: Int, sub: Int, count subCount: Int) -> CGPoint {
        point(
            degrees: subAngle(parent: parent, sub: sub, count: subCount),
            radius: (Self.subInner + Self.subOuter) / 2
        )
    }

    func subIndex(at location: CGPoint, parent: Int, count subCount: Int) -> Int? {
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = hypot(dx, dy)
        guard subCount > 0, distance >= Self.subInner, distance <= Self.subOuter else { return nil }

        let degrees = atan2(Double(dx), Double(-dy)) * 180 / .pi
        for sub in 0..<subCount {
            var diff = degrees - subAngle(parent: parent, sub: sub, count: subCount)
            diff = (diff + 540).truncatingRemainder(dividingBy: 360) - 180
            if abs(diff) <= Self.subSpan / 2 { return sub }
        }
        return nil
    }

    func subSegmentPath(parent: Int, sub: Int, count subCount: Int) -> Path {
        wedgePath(
            centerDegrees: subAngle(parent: parent, sub: sub, count: subCount),
            span: Self.subSpan,
            inner: Self.subInner,
            outer: Self.subOuter
        )
    }

    /// Satu slice berbentuk juring. Kedua tepi radialnya sejajar sehingga celah selalu rata.
    func segmentPath(index: Int) -> Path {
        wedgePath(centerDegrees: Double(index) * step, span: step, inner: inner, outer: outer)
    }

    func wedgePath(centerDegrees: Double, span: Double, inner: CGFloat, outer: CGFloat) -> Path {
        let boundaryStart = centerDegrees - span / 2
        let boundaryEnd = boundaryStart + span
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

struct SubSegmentShape: Shape {
    let geometry: RingGeometry
    let parent: Int
    let sub: Int
    let count: Int

    func path(in rect: CGRect) -> Path {
        geometry.subSegmentPath(parent: parent, sub: sub, count: count)
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

    private let canvas: CGFloat = 380
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
        let subItems = hovered?.children ?? []
        let subHovered = model.subHovered.flatMap { subItems.indices.contains($0) ? subItems[$0] : nil }

        ZStack {
            // Piringan latar memakai material native macOS
            Circle()
                .fill(.regularMaterial)
                .frame(width: (outer + 8) * 2, height: (outer + 8) * 2)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
                .position(geometry.center)

            ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                let isHovered = model.hovered == index
                SegmentShape(geometry: geometry, index: index)
                    .fill(isHovered ? item.tint.opacity(0.9) : segmentColor)
                    .overlay(
                        SegmentShape(geometry: geometry, index: index)
                            .stroke(segmentColor, lineWidth: 1)
                    )

                SliceIcon(icon: item.icon, isHovered: isHovered)
                    .scaleEffect(isHovered ? 1.12 : 1)
                    .position(geometry.iconAnchor(index: index, lift: 0))
            }

            // Sub ring: tombol bulat di luar slice yang disorot
            if let parent = model.hovered, !subItems.isEmpty {
                ForEach(Array(subItems.enumerated()), id: \.element.id) { sub, child in
                    let isSubHovered = model.subHovered == sub
                    let shape = SubSegmentShape(
                        geometry: geometry, parent: parent, sub: sub, count: subItems.count
                    )
                    ZStack {
                        shape.fill(.regularMaterial)
                        shape.fill(isSubHovered ? child.tint.opacity(0.9) : segmentColor)
                        shape.stroke(segmentColor, lineWidth: 1)
                        SliceIcon(icon: child.icon, isHovered: isSubHovered)
                            .scaleEffect(isSubHovered ? 1.12 : 0.85)
                            .position(geometry.subIconAnchor(parent: parent, sub: sub, count: subItems.count))
                    }
                    .transition(.opacity)
                }
                .id(hovered?.id)
            }

            // Pusat ring: ikon slice yang disorot, atau logo Shortqut jika tidak ada
            Circle()
                .fill(.thinMaterial)
                .frame(width: (inner - 6) * 2, height: (inner - 6) * 2)
                .position(geometry.center)

            Group {
                if let shown = subHovered ?? hovered {
                    SliceIcon(icon: shown.icon, isHovered: false)
                } else {
                    Image(systemName: "circle.grid.cross")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .id((subHovered ?? hovered)?.id)
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
            .position(geometry.center)
        }
        .frame(width: canvas, height: canvas)
        .contentShape(Rectangle())
        .scaleEffect(model.isOpen ? 1 : 0.6)
        .opacity(model.isOpen ? 1 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: model.hovered)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: model.subHovered)
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                // Selama kursor menuju sub ring, slice induk tetap aktif
                if let parent = model.hovered,
                   let sub = geometry.subIndex(at: location, parent: parent, count: subItems.count) {
                    model.subHovered = sub
                    return
                }
                model.subHovered = nil
                model.hovered = geometry.index(at: location)
            case .ended:
                model.subHovered = nil
                model.hovered = nil
            }
        }
        .onTapGesture {
            model.activate()
        }
    }
}
