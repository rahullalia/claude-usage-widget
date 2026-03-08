#!/usr/bin/env swift
// Run: swift makeIcon.swift
// Generates AppIcon.appiconset with all required macOS sizes.

import AppKit
import CoreGraphics

// MARK: - Drawing

func drawIcon(in rect: CGRect) {
    let bg = NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1) // #1C1C1F deep slate
    bg.setFill()
    NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.22, yRadius: rect.height * 0.22).fill()

    let center = CGPoint(x: rect.midX, y: rect.midY)
    let lineWidth = rect.width * 0.09
    let radius = rect.width * 0.34

    // Track (full ring, 18% opacity)
    let track = NSBezierPath()
    track.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: -270, clockwise: true)
    track.lineWidth = lineWidth
    track.lineCapStyle = .round
    NSColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 0.18).setStroke()
    track.stroke()

    // Arc at ~72% — enough to feel purposeful, not full
    let progress = 0.72
    let endAngle = 90.0 - (progress * 360.0)
    let arc = NSBezierPath()
    arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: endAngle, clockwise: true)
    arc.lineWidth = lineWidth
    arc.lineCapStyle = .round
    NSColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1).setStroke() // amber #F59E0B
    arc.stroke()
}

func makeImage(size: CGFloat) -> NSImage {
    let s = CGSize(width: size, height: size)
    return NSImage(size: s, flipped: false) { rect in
        drawIcon(in: rect)
        return true
    }
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to render \(path)")
        return
    }
    do {
        try png.write(to: URL(fileURLWithPath: path))
        print("✓ \(path)")
    } catch {
        print("✗ \(path): \(error)")
    }
}

// MARK: - Generate

let outDir = "ClaudeUsageWidget/Assets.xcassets/AppIcon.appiconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let sizes: [(name: String, points: CGFloat, scale: CGFloat)] = [
    ("icon_16x16",     16,  1),
    ("icon_16x16@2x",  16,  2),
    ("icon_32x32",     32,  1),
    ("icon_32x32@2x",  32,  2),
    ("icon_128x128",   128, 1),
    ("icon_128x128@2x",128, 2),
    ("icon_256x256",   256, 1),
    ("icon_256x256@2x",256, 2),
    ("icon_512x512",   512, 1),
    ("icon_512x512@2x",512, 2),
]

for entry in sizes {
    let pixels = entry.points * entry.scale
    let img = makeImage(size: pixels)
    savePNG(img, to: "\(outDir)/\(entry.name).png")
}

// MARK: - Contents.json

let json = """
{
  "images" : [
    { "filename" : "icon_16x16.png",      "idiom" : "mac", "scale" : "1x", "size" : "16x16"   },
    { "filename" : "icon_16x16@2x.png",   "idiom" : "mac", "scale" : "2x", "size" : "16x16"   },
    { "filename" : "icon_32x32.png",      "idiom" : "mac", "scale" : "1x", "size" : "32x32"   },
    { "filename" : "icon_32x32@2x.png",   "idiom" : "mac", "scale" : "2x", "size" : "32x32"   },
    { "filename" : "icon_128x128.png",    "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png",    "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png",    "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""

try! json.write(toFile: "\(outDir)/Contents.json", atomically: true, encoding: .utf8)
print("✓ Contents.json")
print("Done. Open Xcode and the AppIcon should appear automatically.")
