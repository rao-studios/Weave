#!/usr/bin/env swift
// WHAT: Render Weave's app icon: a plain weave of graphite threads on linen, each crossing over
//       then under, and one crossing ringed in vermilion: the host, the knot every thread passes
//       through. After Veil's scripts/art/gen-app-icon.swift.
// OUT:  Support/AppIcon/icon_1024.png (the .icns fallback, via make-iconset.sh),
//       Support/AppIcon/AppIcon.icon/Assets/icon_1024.png (the layer macOS 26+ draws), and
//       Sources/WeaveApp/Resources/AppIcon.png (the Dock icon when Weave runs unbundled).
// PIN:  The first two are square, opaque and unrounded, like Ambient's, Veil's and Craft's: the
//       system masks them. The third is drawn on the macOS tile itself (824 of 1024, continuous
//       corners r 185.4, a soft shadow), since nothing masks an icon set at runtime.
// PIN:  AppIcon.icon draws the layer at scale 1: the weave runs edge to edge, as Veil's grid does.
//
//   swift scripts/art/gen-app-icon.swift
//
import AppKit
import SwiftUI

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let squareOutputs = [
    root.appendingPathComponent("Support/AppIcon/icon_1024.png"),
    root.appendingPathComponent("Support/AppIcon/AppIcon.icon/Assets/icon_1024.png"),
]
let dockOutput = root.appendingPathComponent("Sources/WeaveApp/Resources/AppIcon.png")
let size = 1024
let dockSize = 512

// A 100-unit tile. Five warps (vertical) and five wefts (horizontal) at 18, 34, 50, 66, 82, drawn
// whole; then at every crossing the thread on top is drawn again over a small linen gap that cuts
// the one beneath, alternating warp and weft, so the cloth reads over, under, over.
let lines: [Double] = [18, 34, 50, 66, 82]
let linen = "#ece6d8"
let warp = "#34373e"
let weft = "#666a73"
let accent = "#c4502f"
let host = (x: 66.0, y: 34.0)
let width = 5.2, gap = 2.0

var body = ""
for y in lines { body += #"<path d="M-4 \#(y)H104" stroke="\#(weft)" stroke-width="\#(width)"/>"# }
for x in lines { body += #"<path d="M\#(x) -4V104" stroke="\#(warp)" stroke-width="\#(width)"/>"# }
for (i, x) in lines.enumerated() {
    for (j, y) in lines.enumerated() {
        let half = width / 2, cut = half + gap
        if (i + j) % 2 == 0 {
            // The warp lies on top: the weft is cut either side of it.
            body += #"<rect x="\#(x - cut)" y="\#(y - half - 0.2)" width="\#(2 * cut)" height="\#(width + 0.4)" fill="url(#face)"/>"#
            body += #"<path d="M\#(x) \#(y - cut - 1)V\#(y + cut + 1)" stroke="\#(warp)" stroke-width="\#(width)"/>"#
        } else {
            // The weft lies on top: the warp is cut above and below it.
            body += #"<rect x="\#(x - half - 0.2)" y="\#(y - cut)" width="\#(width + 0.4)" height="\#(2 * cut)" fill="url(#face)"/>"#
            body += #"<path d="M\#(x - cut - 1) \#(y)H\#(x + cut + 1)" stroke="\#(weft)" stroke-width="\#(width)"/>"#
        }
    }
}
// The host: the crossing cleared to linen, ringed in vermilion, a knot at its heart.
let ring = #"""
  <circle cx="\#(host.x)" cy="\#(host.y)" r="10.6" fill="url(#face)"/>
  <circle cx="\#(host.x)" cy="\#(host.y)" r="8.4" fill="none" stroke="\#(accent)" stroke-width="2.6"/>
  <circle cx="\#(host.x)" cy="\#(host.y)" r="3.1" fill="\#(accent)"/>
"""#

let svg = """
<svg xmlns="http://www.w3.org/2000/svg" width="\(size)" height="\(size)" viewBox="0 0 100 100">
  <defs>
    <linearGradient id="face" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="100" y2="100">
      <stop offset="0" stop-color="#f3eee3"/>
      <stop offset="0.6" stop-color="\(linen)"/>
      <stop offset="1" stop-color="#d3cbba"/>
    </linearGradient>
  </defs>
  <rect width="100" height="100" fill="url(#face)"/>
  <g>\(body)</g>
\(ring)
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
