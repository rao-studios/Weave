#!/usr/bin/env swift
// WHAT: Render Weave's app icon: a knitted cloth (stockinette, rows of V stitches in graphite
//       yarn) with a steel needle laid across it, a vermilion thread through its eye running
//       down and stitched into the cloth. The thread is what Weave adds: one line through every
//       piece. After Veil's Scripts/art/gen-app-icon.swift.
// OUT:  Support/AppIcon/icon_1024.png (the .icns fallback, via make-iconset.sh),
//       Support/AppIcon/AppIcon.icon/Assets/icon_1024.png (the layer macOS 26+ draws), and
//       Sources/WeaveApp/Resources/AppIcon.png (the Dock icon when Weave runs unbundled, and the
//       app's own mark in the sidebar), and Docs/README_Assets/icon.png (beside the README's brief).
// PIN:  The first two are square, opaque and unrounded, like Ambient's, Veil's and Craft's: the
//       system masks them. The third is drawn on the macOS tile itself (824 of 1024, continuous
//       corners r 185.4, a soft shadow), since nothing masks an icon set at runtime.
// PIN:  AppIcon.icon draws the layer at scale 1: the cloth runs edge to edge, as Veil's grid does.
//
//   swift Scripts/art/gen-app-icon.swift
//
import AppKit
import SwiftUI

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let squareOutputs = [
    root.appendingPathComponent("Support/AppIcon/icon_1024.png"),
    root.appendingPathComponent("Support/AppIcon/AppIcon.icon/Assets/icon_1024.png"),
]
let dockOutput = root.appendingPathComponent("Sources/WeaveApp/Resources/AppIcon.png")
/// The same tile, beside the README's brief.
let readmeOutput = root.appendingPathComponent("Docs/README_Assets/icon.png")
let size = 1024
let dockSize = 512

// A 100-unit tile. Stockinette in cream yarn: columns 12.5 apart, rows 8.6 apart; each stitch is
// a V of two leaf-shaped legs, tilted 30 degrees, over the darker shadow of the knit between them.
let linen = "#ece6d8"
let gaps = "#9d937f"
let yarn = "#ede6d6"
let yarnEdge = "#b3a993"
let yarnLight = "#fbf8f1"
let accent = "#c4502f"
let accentDark = "#8f3519"

var cloth = #"<rect width="100" height="100" fill="\#(gaps)"/>"#
for row in -1...12 {
    let cy = 4.3 + 8.6 * Double(row)
    for column in -1...8 {
        let cx = 6.25 + 12.5 * Double(column)
        for side in [-1.0, 1.0] {
            let lx = cx + side * 2.95, tilt = side * 30
            cloth += #"<g transform="translate(\#(lx) \#(cy)) rotate(\#(tilt))">"#
            cloth += ##"<ellipse cx="0.35" cy="0.7" rx="3.05" ry="6.0" fill="#000" fill-opacity="0.16"/>"##
            cloth += #"<ellipse rx="3.05" ry="6.0" fill="\#(yarn)" stroke="\#(yarnEdge)" stroke-width="0.45"/>"#
            cloth += #"<ellipse cx="-0.7" cy="-1.4" rx="1.0" ry="3.3" fill="\#(yarnLight)" fill-opacity="0.9"/>"#
            cloth += "</g>"
        }
    }
}

// The needle, laid along a diagonal: drawn on its own axis (tip at -50, eye near +40), then
// rotated into place. A soft shadow, a steel body, a highlight, and the eye's slot.
let needleCenter = (x: 50.0, y: 50.0), needleAngle = -42.0
let needle = #"""
  <g transform="translate(\#(needleCenter.x) \#(needleCenter.y)) rotate(\#(needleAngle))">
    <path d="M-51 1.6L-38 3.7L44 3.9Q50.5 3.9 50.5 0.8Q50.5 -2.3 44 -2.3L-38 -1.9Z" fill="#000" fill-opacity="0.28" transform="translate(1.2 2.2)"/>
    <path d="M-51 0L-38 -2.2L44 -2.6Q50.5 -2.6 50.5 0Q50.5 2.6 44 2.6L-38 2.2Z" fill="url(#steel)" stroke="#5f646c" stroke-width="0.35"/>
    <path d="M-36 -1.3L44 -1.6" stroke="#ffffff" stroke-opacity="0.75" stroke-width="0.7" stroke-linecap="round"/>
    <rect x="37.5" y="-0.75" width="9" height="1.5" rx="0.75" fill="#2b2d33"/>
  </g>
"""#
// The eye in tile coordinates, for the thread.
let radians = needleAngle * .pi / 180
let eye = (x: needleCenter.x + 42 * cos(radians), y: needleCenter.y + 42 * sin(radians))

// The thread: out of the eye, a loose loop to the right, then down into the cloth, where it runs
// as a stitched line across a row (over a stitch, under the next).
let tail = "M\(eye.x) \(eye.y)C\(eye.x + 14) \(eye.y + 2) \(eye.x + 12) \(eye.y + 26) \(eye.x - 4) \(eye.y + 34)S\(eye.x - 30) \(eye.y + 42) 48 77.7"
let run = "M48 77.7H-2"
let thread = #"""
  <path d="\#(tail)" fill="none" stroke="#000" stroke-opacity="0.22" stroke-width="3.4" stroke-linecap="round" transform="translate(0.9 1.6)"/>
  <path d="\#(tail)" fill="none" stroke="\#(accentDark)" stroke-width="2.9" stroke-linecap="round" transform="translate(0.4 0.6)"/>
  <path d="\#(tail)" fill="none" stroke="\#(accent)" stroke-width="2.6" stroke-linecap="round"/>
  <path d="\#(run)" fill="none" stroke="\#(accentDark)" stroke-width="2.9" stroke-linecap="round" stroke-dasharray="6.5 6" transform="translate(0.3 0.5)"/>
  <path d="\#(run)" fill="none" stroke="\#(accent)" stroke-width="2.6" stroke-linecap="round" stroke-dasharray="6.5 6"/>
"""#

let svg = """
<svg xmlns="http://www.w3.org/2000/svg" width="\(size)" height="\(size)" viewBox="0 0 100 100">
  <defs>
    <linearGradient id="face" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="100" y2="100">
      <stop offset="0" stop-color="#f3eee3"/>
      <stop offset="0.6" stop-color="\(linen)"/>
      <stop offset="1" stop-color="#d3cbba"/>
    </linearGradient>
    <linearGradient id="steel" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#f4f5f7"/>
      <stop offset="0.45" stop-color="#c3c8cf"/>
      <stop offset="1" stop-color="#7f858e"/>
    </linearGradient>
  </defs>
  <g>\(cloth)</g>
\(thread)
\(needle)
</svg>
"""

let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("weave-app-icon-\(UUID()).svg")
try svg.write(to: tmp, atomically: true, encoding: .utf8)
defer { try? FileManager.default.removeItem(at: tmp) }
guard let art = NSImage(contentsOf: tmp) else { fatalError("could not load the icon SVG") }

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func render(_ pixels: Int, alpha: Bool, draw: (CGContext) -> Void) -> CGImage {
    let info = alpha ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast
    guard let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: info.rawValue) else { fatalError("no bitmap context") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    draw(context)
    NSGraphicsContext.restoreGraphicsState()
    guard let image = context.makeImage() else { fatalError("could not render the icon") }
    return image
}

func write(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        fatalError("could not write \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(url.path)") }
    print("wrote \(url.path.replacingOccurrences(of: root.path + "/", with: ""))")
}

let square = render(size, alpha: false) { _ in art.draw(in: NSRect(x: 0, y: 0, width: size, height: size)) }
for url in squareOutputs { try write(square, to: url) }

let dock = render(dockSize, alpha: true) { context in
    let unit = CGFloat(dockSize) / 1024
    let tile = CGRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
    let shape = RoundedRectangle(cornerRadius: 185.4 * unit, style: .continuous).path(in: tile).cgPath
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10 * unit), blur: 24 * unit, color: CGColor(gray: 0, alpha: 0.3))
    context.addPath(shape)
    context.setFillColor(CGColor(gray: 0.88, alpha: 1))
    context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addPath(shape)
    context.clip()
    art.draw(in: tile)
    context.restoreGState()
    context.addPath(shape)
    context.setStrokeColor(CGColor(gray: 0, alpha: 0.12))
    context.setLineWidth(2 * unit)
    context.strokePath()
}
try write(dock, to: dockOutput)
try write(dock, to: readmeOutput)
