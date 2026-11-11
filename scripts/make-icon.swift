// Makes branding/Hollow.icns from a square logo render whose icon sits on a flat background.
//
//   swift scripts/make-icon.swift branding/logo-dark.png <x> <y> <side>
//
// x, y, side: the icon's rounded square inside the source image, in pixels.
// Output follows Apple's macOS grid: 1024 canvas, 824 body, soft drop shadow.
import AppKit

let args = CommandLine.arguments
guard args.count == 5, let x = Double(args[2]), let y = Double(args[3]), let side = Double(args[4]),
      let src = NSImage(contentsOfFile: args[1]) else {
    print("usage: swift scripts/make-icon.swift <logo.png> <x> <y> <side>"); exit(1)
}
let srcRep = src.representations.first!
let scale = Double(srcRep.pixelsWide) / src.size.width   // points ↔ pixels in the source

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let k = Double(px) / 1024
    let body = NSRect(x: 100 * k, y: 100 * k, width: 824 * k, height: 824 * k)
    // Inset 2% so the source's background never shows at the edge.
    let clip = NSBezierPath(roundedRect: body, xRadius: 185 * k, yRadius: 185 * k)

    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 20 * k
    shadow.shadowOffset = NSSize(width: 0, height: -8 * k)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.black.setFill()
    clip.fill()
    NSGraphicsContext.restoreGraphicsState()

    clip.addClip()
    let inset = side * 0.02
    let from = NSRect(x: (x + inset) / scale,
                      y: (Double(srcRep.pixelsHigh) - y - side + inset) / scale,   // flip: AppKit's origin is bottom-left
                      width: (side - 2 * inset) / scale, height: (side - 2 * inset) / scale)
    src.draw(in: body, from: from, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let set = URL(filePath: NSTemporaryDirectory()).appending(path: "Hollow.iconset")
try? fm.removeItem(at: set)
try! fm.createDirectory(at: set, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try! render(size).write(to: set.appending(path: "icon_\(size)x\(size).png"))
    try! render(size * 2).write(to: set.appending(path: "icon_\(size)x\(size)@2x.png"))
}
try! render(1024).write(to: URL(filePath: "branding/AppIcon-1024.png"))

let p = Process()
p.executableURL = URL(filePath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", set.path, "-o", "branding/Hollow.icns"]
try! p.run(); p.waitUntilExit()
print(p.terminationStatus == 0 ? "wrote branding/Hollow.icns" : "iconutil failed")
