//
//  Design.swift
//  Weave
//
//  Palette, typography and metrics: the Rao editorial language (warm paper, ink text, one accent),
//  with Weave's own: linen and graphite, and vermilion for the host, the one knot every thread
//  passes through.
//

import AppKit
import SwiftUI
import WeaveKit

extension Color {
    static let weaveBG = Color(red: 246 / 255, green: 243 / 255, blue: 236 / 255)
    static let weaveInk = Color(red: 44 / 255, green: 46 / 255, blue: 52 / 255)
    static let weaveAccent = Color(red: 196 / 255, green: 80 / 255, blue: 47 / 255)
    static let weaveThread = Color(red: 58 / 255, green: 61 / 255, blue: 68 / 255)
    static var weaveBorder: Color { Color.weaveInk.opacity(0.12) }
    static var weaveCard: Color { Color.white.opacity(0.66) }
    static var weaveFill: Color { Color.weaveInk.opacity(0.05) }
    static let weaveError = Color(red: 196 / 255, green: 64 / 255, blue: 56 / 255)
    static let weaveGreen = Color(red: 84 / 255, green: 146 / 255, blue: 98 / 255)
    static let weaveAmber = Color(red: 206 / 255, green: 146 / 255, blue: 50 / 255)
    static let weaveBlue = Color(red: 78 / 255, green: 112 / 255, blue: 168 / 255)
}

enum WeaveMetrics {
    static let windowSize = CGSize(width: 1180, height: 780)
    static let sidebarWidth: CGFloat = 230
    static let detailMinWidth: CGFloat = 700
    static let contentMinHeight: CGFloat = 560
    static let toolbarAllowance: CGFloat = 52
    static var windowMinSize: CGSize { CGSize(width: sidebarWidth + 1 + detailMinWidth, height: contentMinHeight + toolbarAllowance) }
    static let controlHeight: CGFloat = 26
    static let pagePadding: CGFloat = 24
    static let readingWidth: CGFloat = 760
    /// The label column every labelled row on a page shares, so values and controls line up.
    static let labelColumn: CGFloat = 150
}

extension Font {
    static func weaveSerif(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        let f = Font.system(size: size, weight: weight, design: .serif)
        return italic ? f.italic() : f
    }

    static func weaveSans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }

    static func weaveMono(_ size: CGFloat) -> Font { .system(size: size, design: .monospaced) }
}

/// A small status dot: green up, amber starting, red down, grey unknown.
struct StatusDot: View {
    enum State { case ok, warn, off, unknown }
    let state: State
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(color.opacity(0.3), lineWidth: 2).frame(width: size + 4, height: size + 4))
    }

    private var color: Color {
        switch state {
        case .ok: return .weaveGreen
        case .warn: return .weaveAmber
        case .off: return .weaveError
        case .unknown: return Color.weaveInk.opacity(0.25)
        }
    }
}

extension StatusDot.State {
    init(_ status: ThreadStatus) {
        switch status {
        case .up: self = .ok
        case .starting: self = .warn
        case .unhealthy: self = .off
        case .stopped: self = .unknown
        }
    }

    init(_ status: ServerStatus) {
        switch status {
        case .up: self = .ok
        case .starting: self = .warn
        case .down: self = .off
        case .unknown: self = .unknown
        }
    }
}

struct Pill: View {
    let text: String
    var tint: Color = .weaveInk
    var body: some View {
        Text(text)
            .font(.weaveMono(9.5))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.10))
            .foregroundStyle(tint)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .fixedSize()
    }
}

/// A section caption in small tracked capitals.
struct SectionCaption: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.weaveSans(9.5))
            .tracking(1.3)
            .foregroundStyle(Color.weaveInk.opacity(0.4))
    }
}

struct WeaveButtonStyle: ButtonStyle {
    var prominent = false
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        let tint: Color = destructive ? .weaveError : (prominent ? .weaveAccent : .weaveInk)
        configuration.label
            .font(.weaveSans(11.5, weight: prominent ? .semibold : .regular))
            .padding(.horizontal, 10)
            .frame(minHeight: WeaveMetrics.controlHeight)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(prominent ? tint.opacity(configuration.isPressed ? 0.75 : 0.92) : tint.opacity(configuration.isPressed ? 0.14 : 0.07))
            )
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(tint.opacity(prominent ? 0 : 0.18), lineWidth: 1))
            .foregroundStyle(prominent ? Color.white : tint)
            .contentShape(Rectangle())
    }
}

/// The mark: the app icon's tile (knitted cloth, a needle, a vermilion thread), rendered by
/// Scripts/art/gen-app-icon.swift into Resources/AppIcon.png.
struct WeaveMark: View {
    var size: CGFloat = 22

    static let image: NSImage? = Bundle.module.url(forResource: "AppIcon", withExtension: "png").flatMap(NSImage.init(contentsOf:))

    var body: some View {
        Group {
            if let image = Self.image {
                Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "scissors").resizable().aspectRatio(contentMode: .fit).foregroundStyle(Color.weaveAccent)
            }
        }
        // The tile is drawn inset on a 1024 grid (824 of it): scale up so its edge meets the frame.
        .frame(width: size * 1024 / 824, height: size * 1024 / 824)
        .frame(width: size, height: size)
    }
}

enum Formatters {
    static func ms(_ v: Double) -> String { v < 1000 ? String(format: "%.0f ms", v) : String(format: "%.2f s", v / 1000) }
    static func ago(_ date: Date?) -> String {
        guard let date else { return "never" }
        let s = Int(Date().timeIntervalSince(date))
        return s < 5 ? "just now" : s < 60 ? "\(s) s ago" : "\(s / 60) min ago"
    }
}
