// Renders app/AppIcon.icns: an SF Symbol on a dark rounded tile. Run: swift make-icon.swift (from app/).
import AppKit

let sizes: [(String, Int)] = [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                              ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)]
let iconset = URL(fileURLWithPath: "AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = s * 0.1
    let tile = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.22, yRadius: tile.width * 0.22)
    NSGradient(starting: NSColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 1),
               ending: NSColor(red: 0.20, green: 0.05, blue: 0.10, alpha: 1))!.draw(in: path, angle: -90)
    NSColor(red: 0.0, green: 0.95, blue: 0.85, alpha: 0.9).setStroke()
    path.lineWidth = max(1, s * 0.012)
    path.stroke()
    let config = NSImage.SymbolConfiguration(pointSize: s * 0.42, weight: .semibold)
        .applying(.init(paletteColors: [NSColor(red: 0.98, green: 0.92, blue: 0.10, alpha: 1)]))
    if let symbol = NSImage(systemSymbolName: "bandage.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let r = NSRect(x: (s - symbol.size.width) / 2, y: (s - symbol.size.height) / 2, width: symbol.size.width, height: symbol.size.height)
        symbol.draw(in: r)
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (name, px) in sizes {
    try render(px).write(to: iconset.appendingPathComponent("icon_\(name).png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "AppIcon.icns"]
try p.run()
p.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print(p.terminationStatus == 0 ? "wrote AppIcon.icns" : "iconutil failed")
