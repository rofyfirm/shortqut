// Menggambar ikon Shortqut 1024×1024 (gaya macOS: kotak membulat dengan margin).
// Pemakaian: swift scripts/make-icon.swift <output.png>
import AppKit

let canvas = 1024
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: canvas,
    pixelsHigh: canvas,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("Gagal membuat bitmap")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let cg = context.cgContext

// Area ikon macOS: 824 pt di dalam kanvas 1024 pt, radius sudut ±185
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

// Bayangan lembut di bawah kotak
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -12), blur: 28,
             color: NSColor.black.withAlphaComponent(0.35).cgColor)
cg.addPath(bodyPath)
cg.setFillColor(NSColor(srgbRed: 0.25, green: 0.4, blue: 0.95, alpha: 1).cgColor)
cg.fillPath()
cg.restoreGState()

// Gradasi biru
cg.saveGState()
cg.addPath(bodyPath)
cg.clip()
let gradientColors = [
    NSColor(srgbRed: 0.42, green: 0.62, blue: 1.00, alpha: 1).cgColor,
    NSColor(srgbRed: 0.16, green: 0.20, blue: 0.80, alpha: 1).cgColor,
] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: gradientColors, locations: [0, 1])!
cg.drawLinearGradient(gradient,
                      start: CGPoint(x: 512, y: 924),
                      end: CGPoint(x: 512, y: 100),
                      options: [])

// Sorotan halus di bagian atas
let highlight = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [NSColor.white.withAlphaComponent(0.18).cgColor,
                                    NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
                           locations: [0, 1])!
cg.drawLinearGradient(highlight,
                      start: CGPoint(x: 512, y: 924),
                      end: CGPoint(x: 512, y: 560),
                      options: [])
cg.restoreGState()

// Glyph: empat slice berjarak seperti ring aksi, dengan lingkaran di tengah
let center = CGPoint(x: 512, y: 512)
let outerRadius: CGFloat = 270
let innerRadius: CGFloat = 130
let glyphColor = NSColor.white.withAlphaComponent(0.95).cgColor

for index in 0..<4 {
    let startDegrees = Double(index) * 90 + 8
    let endDegrees = startDegrees + 74
    let start = CGFloat(startDegrees * .pi / 180)
    let end = CGFloat(endDegrees * .pi / 180)

    let slice = CGMutablePath()
    slice.addArc(center: center, radius: outerRadius,
                 startAngle: start, endAngle: end, clockwise: false)
    slice.addArc(center: center, radius: innerRadius,
                 startAngle: end, endAngle: start, clockwise: true)
    slice.closeSubpath()

    cg.addPath(slice)
    cg.setFillColor(glyphColor)
    cg.fillPath()
}

cg.setFillColor(glyphColor)
cg.fillEllipse(in: CGRect(x: center.x - 92, y: center.y - 92, width: 184, height: 184))

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Gagal membuat PNG")
}
try png.write(to: URL(fileURLWithPath: outputPath))
print("Tersimpan: \(outputPath)")
