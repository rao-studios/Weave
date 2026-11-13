//
//  ThreadRow.swift
//  Weave
//
//  One spawned AII, as a card in the Fabric's grid or a row in its list: its node mark and name, its
//  state, its Thread's ports, its counts in Weave's lane, its models, and its controls. Every block
//  is a Grid, so the labels, the numbers and the buttons line up from card to card; in the list the
//  mark leads each row and the counts keep one width, so they line up from row to row.
//

import Granite
import SwiftUI
import WeaveKit

/// What a card asks for, routed by the Fabric page.
struct ThreadRowAction: Sendable, Equatable {
    enum Kind: Sendable, Equatable { case start, stop, restart, explore, remove, reveal, weaveIn, weaveOut, host, connect }
    let name: String
    let kind: Kind
}

struct ThreadRow: View {
    /// A card in the grid, or a row in the list.
    enum Style { case card, row }

    let record: ThreadRecord
    let status: ThreadStatus
    let embedder: ThreadEmbedderState?
    let extractor: String?
    let counts: ThreadCounts?
    let shape: LaunchShape?
    let isHost: Bool
    let busy: Bool
    let needsReseed: Bool
    let registered: Bool
    var style: Style = .card
    @Environment(\.graniteBubble) private var bubble

    /// The counts' width in a list row: one width for every row, so the numbers line up.
    static let rowMetricsWidth: CGFloat = 300

    var body: some View {
        Group {
            switch style {
            case .card: card
            case .row: row
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.weaveCard))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isHost ? Color.weaveAccent.opacity(0.45) : Color.weaveBorder, lineWidth: 1))
    }

    // MARK: - Arrangements

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                mark
                identity
                Spacer(minLength: 0)
                spinner
                menu
            }
            Divider().overlay(Color.weaveBorder)
            details
            metrics
            notes
            Spacer(minLength: 0)
            controls(spread: true)
        }
    }

    /// The mark leads; the name and the controls share the first line, the details and the counts the second.
    private var row: some View {
        HStack(alignment: .top, spacing: 14) {
            mark
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    identity
                    Spacer(minLength: 12)
                    spinner
                    controls(spread: false)
                    menu
                }
                Divider().overlay(Color.weaveBorder)
                HStack(alignment: .center, spacing: 18) {
                    details
                    Spacer(minLength: 12)
                    metrics.frame(width: Self.rowMetricsWidth)
                }
                notes
            }
        }
    }

    // MARK: - Blocks

    private var mark: some View {
        NodeMark(status: status, isHost: isHost, woven: record.woven)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(record.name).font(.weaveSerif(19, weight: .medium, italic: true)).foregroundStyle(Color.weaveInk)
                if isHost { Pill(text: "host", tint: .weaveAccent) }
            }
            HStack(spacing: 6) {
                StatusDot(state: StatusDot.State(status), size: 6)
                Text(verbatim: status.label + (status.detail.map { " · \($0)" } ?? ""))
                    .font(.weaveMono(10.5)).foregroundStyle(Color.weaveInk.opacity(0.55)).lineLimit(1)
            }
        }
    }

    @ViewBuilder private var spinner: some View {
        if busy { ProgressView().controlSize(.small) }
    }

    private var details: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 7) {
            GridRow {
                label("Thread")
                Text(verbatim: "http \(record.threadHTTP)").font(.weaveMono(11))
                Text(verbatim: "grpc \(record.threadGRPC)").font(.weaveMono(11))
            }
            GridRow {
                label("Fabric")
                Pill(text: record.woven ? (registered ? "woven · registered" : "woven") : "loose", tint: record.woven ? .weaveBlue : .weaveInk)
                Pill(text: record.graphBackend == "mlx" ? "graph · on device" : "graph · keywords")
            }
            GridRow {
                label("Models")
                Pill(text: "embedder · \(embedder?.phase.rawValue ?? "—")", tint: embedder?.phase == .ready ? .weaveGreen : .weaveAmber)
                Pill(text: "extractor · \(extractor ?? "—")")
            }
        }
    }

    private var metrics: some View {
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 2) {
            GridRow {
                number(counts?.documents); number(counts?.groups); number(counts?.entities); number(counts?.relationships)
            }
            GridRow {
                caption("documents"); caption("groups"); caption("entities"); caption("relations")
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.weaveFill))
    }

    @ViewBuilder private var notes: some View {
        if needsReseed {
            Note("Its fabric secret is stale (Weave's secret in ~/.rao changed). It is re-seeded at its next start.")
                .foregroundStyle(Color.weaveAmber)
        }
        if status.isRunning, record.woven, let shape, shape.mothershipGRPCPort == nil {
            Note("Running standalone: restart it to register with the host.")
        }
    }

    /// `spread`: Explore at the far edge (a card); else after the rest (a row, where a spacer leads).
    private func controls(spread: Bool) -> some View {
        HStack(spacing: 6) {
            if status.isRunning {
                Button("Stop") { send(.stop) }.buttonStyle(WeaveButtonStyle())
                Button("Restart") { send(.restart) }.buttonStyle(WeaveButtonStyle())
            } else {
                Button("Start") { send(.start) }.buttonStyle(WeaveButtonStyle(prominent: true))
            }
            Button(record.woven ? "Weave out" : "Weave in") { send(record.woven ? .weaveOut : .weaveIn) }.buttonStyle(WeaveButtonStyle())
            if spread { Spacer(minLength: 0) }
            Button { send(.explore) } label: { Label("Explore", systemImage: "arrow.right") .labelStyle(.titleAndIcon) }
                .buttonStyle(WeaveButtonStyle(prominent: status.isRunning))
        }
        .disabled(busy)
    }

    private var menu: some View {
        Menu {
            Button("Request Examples…") { send(.connect) }
            Button("Make Host") { send(.host) }.disabled(isHost)
            Button("Reveal Home in Finder") { send(.reveal) }
            Divider()
            Button("Remove…", role: .destructive) { send(.remove) }
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.weaveInk.opacity(0.55))
                .frame(width: 26, height: 22)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.weaveFill))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(busy)
    }

    // MARK: - Pieces

    private func label(_ text: String) -> some View {
        Text(text).font(.weaveSans(11)).foregroundStyle(Color.weaveInk.opacity(0.45)).gridColumnAlignment(.leading)
    }

    private func number(_ value: Int?) -> some View {
        Text(value.map(String.init) ?? "–").font(.weaveSerif(22, weight: .medium)).foregroundStyle(Color.weaveInk)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.weaveSans(10.5)).foregroundStyle(Color.weaveInk.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func send(_ kind: ThreadRowAction.Kind) {
        bubble(.threadRowAction, ThreadRowAction(name: record.name, kind: kind))
    }
}

/// An AII node: a core holding its index, ringed, with three links out to the cloth it is woven
/// into. Green up, amber starting, red unhealthy, grey stopped; the host's ring is vermilion; a loose
/// AII's links are dashed.
struct NodeMark: View {
    let status: ThreadStatus
    let isHost: Bool
    let woven: Bool
    var size: CGFloat = 40

    var body: some View {
        Canvas { context, canvas in
            let s = canvas.width
            let c = CGPoint(x: s / 2, y: s / 2)
            let tint = color
            // The tile.
            context.fill(Path(roundedRect: CGRect(origin: .zero, size: canvas), cornerRadius: s * 0.26),
                         with: .color(tint.opacity(0.10)))
            // Links to three satellites.
            let r = s * 0.33
            let angles: [Double] = [-90, 30, 150]
            let style = StrokeStyle(lineWidth: s * 0.045, lineCap: .round, dash: woven ? [] : [s * 0.07, s * 0.06])
            for angle in angles {
                let a = angle * .pi / 180
                let p = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
                context.stroke(Path { $0.move(to: c); $0.addLine(to: p) }, with: .color(Color.weaveThread.opacity(0.45)), style: style)
                let d = s * 0.13
                context.fill(Path(ellipseIn: CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)), with: .color(Color.weaveThread.opacity(0.7)))
            }
            // The core: a ring, its index inside.
            let ring = s * 0.36
            let core = CGRect(x: c.x - ring / 2, y: c.y - ring / 2, width: ring, height: ring)
            context.fill(Path(ellipseIn: core), with: .color(Color.weaveBG))
            context.stroke(Path(ellipseIn: core), with: .color(isHost ? .weaveAccent : tint), lineWidth: s * 0.06)
            let dot = s * 0.14
            context.fill(Path(ellipseIn: CGRect(x: c.x - dot / 2, y: c.y - dot / 2, width: dot, height: dot)), with: .color(tint))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("AII node, \(status.label)\(isHost ? ", host" : "")")
    }

    private var color: Color {
        switch status {
        case .up: return .weaveGreen
        case .starting: return .weaveAmber
        case .unhealthy: return .weaveError
        case .stopped: return Color.weaveInk.opacity(0.45)
        }
    }
}

extension GraniteBubble.Name {
    static let threadRowAction: Self = "ThreadRow.action"
}
