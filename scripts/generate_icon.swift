#!/usr/bin/env swift
// Draws the keySwitcher app icon (an "A" keycap between two circulating
// arrows on a dark emerald squircle) and writes AppIcon.appiconset PNGs.
// Run from the repo root:
//   swift scripts/generate_icon.swift
import AppKit

let canvas: CGFloat = 1024

// MARK: - Drawing helpers

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

/// One circulating arrow: an arc plus a filled arrowhead tangent to the
/// circle at the arc's end. Angles are degrees, the arc runs clockwise.
func drawArrow(from startDeg: CGFloat, to endDeg: CGFloat, color fill: NSColor) {
    let center = NSPoint(x: 512, y: 512)
    let radius: CGFloat = 302
    let lineWidth: CGFloat = 58

    let arc = NSBezierPath()
    arc.appendArc(withCenter: center, radius: radius, startAngle: startDeg, endAngle: endDeg, clockwise: true)
    arc.lineWidth = lineWidth
    arc.lineCapStyle = .round
    fill.setStroke()
    arc.stroke()

    let rad = endDeg * .pi / 180
    let end = NSPoint(x: center.x + radius * cos(rad), y: center.y + radius * sin(rad))
    let tangent = NSPoint(x: sin(rad), y: -cos(rad)) // clockwise travel direction
    let outward = NSPoint(x: cos(rad), y: sin(rad))
    let tipLength: CGFloat = 120
    let halfWidth: CGFloat = 95

    let head = NSBezierPath()
    head.move(to: NSPoint(x: end.x + tangent.x * tipLength, y: end.y + tangent.y * tipLength))
    head.line(to: NSPoint(x: end.x + outward.x * halfWidth, y: end.y + outward.y * halfWidth))
    head.line(to: NSPoint(x: end.x - outward.x * halfWidth, y: end.y - outward.y * halfWidth))
    head.close()
    fill.setFill()
    head.fill()
}

// MARK: - Render at 1024

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Squircle background on the standard macOS icon grid: 824×824 centered.
let plate = NSRect(x: 100, y: 100, width: 824, height: 824)
do {
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowBlurRadius = 24
    shadow.set()
    let squircle = NSBezierPath(roundedRect: plate, xRadius: 186, yRadius: 186)
    NSGradient(colors: [color(0x04352D), color(0x11705B)])?.draw(in: squircle, angle: 90)
    NSGraphicsContext.current?.restoreGraphicsState()

    // Subtle top sheen so the plate doesn't look flat.
    let sheenRect = NSRect(x: plate.minX, y: plate.midY, width: plate.width, height: plate.height / 2)
    let sheen = NSBezierPath(roundedRect: sheenRect, xRadius: 186, yRadius: 186)
    NSGradient(colors: [color(0xFFFFFF, alpha: 0), color(0xFFFFFF, alpha: 0.10)])?.draw(in: sheen, angle: 90)
}

// Mint arrow over the top, amber arrow under the bottom (point-symmetric).
drawArrow(from: 150, to: 32, color: color(0x4FE3BC))
drawArrow(from: 330, to: 212, color: color(0xFFB84D))

// The "A" keycap, drawn over the arrows.
do {
    let rect = NSRect(x: 327, y: 327, width: 370, height: 370)
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.32)
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.shadowBlurRadius = 26
    shadow.set()
    let radius = rect.width * 0.20
    color(0xB0BAC9).setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    let faceInset = rect.height * 0.055
    let faceRect = NSRect(x: rect.minX, y: rect.minY + faceInset, width: rect.width, height: rect.height - faceInset)
    NSGradient(colors: [color(0xF0F3F9), NSColor.white])?
        .draw(in: NSBezierPath(roundedRect: faceRect, xRadius: radius, yRadius: radius), angle: 90)

    let font = NSFont.systemFont(ofSize: 220, weight: .bold)
    let text = NSAttributedString(string: "A", attributes: [.font: font, .foregroundColor: color(0x0A4A3D)])
    let size = text.size()
    text.draw(at: NSPoint(x: faceRect.midX - size.width / 2, y: faceRect.midY - size.height / 2))
}

NSGraphicsContext.current?.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

// MARK: - Write the appiconset

let iconsetDir = "keySwitcher/Resources/Assets.xcassets/AppIcon.appiconset"
try FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let master = URL(fileURLWithPath: "\(iconsetDir)/icon_1024.png")
try rep.representation(using: .png, properties: [:])!.write(to: master)

// (filename, pixel size, point size, scale)
let variants: [(String, Int, Int, Int)] = [
    ("icon_16", 16, 16, 1), ("icon_32", 32, 16, 2),
    ("icon_32@1x", 32, 32, 1), ("icon_64", 64, 32, 2),
    ("icon_128", 128, 128, 1), ("icon_256", 256, 128, 2),
    ("icon_256@1x", 256, 256, 1), ("icon_512", 512, 256, 2),
    ("icon_512@1x", 512, 512, 1), ("icon_1024", 1024, 512, 2),
]

let source = NSImage(contentsOf: master)!
for (name, pixels, _, _) in variants where name != "icon_1024" {
    let scaled = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: scaled)
    NSGraphicsContext.current?.imageInterpolation = .high
    source.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    try scaled.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(iconsetDir)/\(name).png"))
}

let images = variants
    .map { name, _, points, scale in
        """
            {
              "filename" : "\(name).png",
              "idiom" : "mac",
              "scale" : "\(scale)x",
              "size" : "\(points)x\(points)"
            }
        """
    }
    .joined(separator: ",\n")
try """
{
  "images" : [
\(images)
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
""".write(toFile: "\(iconsetDir)/Contents.json", atomically: true, encoding: .utf8)

try """
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
""".write(toFile: "keySwitcher/Resources/Assets.xcassets/Contents.json", atomically: true, encoding: .utf8)

print("Icon set written to \(iconsetDir)")
