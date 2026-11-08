//
//  ThreadRow.swift
//  Weave
//
//  One spawned AII: its name and ports, its Thread's state, its embedder and extractor, its counts
//  in Weave's lane, whether the host sees it, and its controls.
//

import Granite
import SwiftUI
import WeaveKit

/// What a row asks for, routed by the Fabric page.
struct ThreadRowAction: Sendable, Equatable {
    enum Kind: Sendable, Equatable { case start, stop, restart, explore, remove, reveal, weaveIn, weaveOut, host }
    let name: String
    let kind: Kind
}

struct ThreadRow: View {
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
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        Card {
            HStack(alignment: .center, spacing: 10) {
                StatusDot(state: StatusDot.State(status))
                Text(record.name).font(.weaveSerif(17, weight: .medium, italic: true))
                if isHost { Pill(text: "host", tint: .weaveAccent) }
                Pill(text: record.woven ? (registered ? "woven · registered" : "woven") : "loose", tint: record.woven ? .weaveBlue : .weaveInk)
                Pill(text: record.graphBackend == "mlx" ? "graph · on device" : "graph · keywords")
                Spacer()
                if busy { ProgressView().controlSize(.small) }
                controls
            }
            HStack(spacing: 18) {
                KeyValueRow(key: "Thread", value: "http \(record.threadHTTP) · grpc \(record.threadGRPC)").frame(maxWidth: 360)
                Text(status.label + (status.detail.map { " · \($0)" } ?? "")).font(.weaveMono(10.5)).foregroundStyle(Color.weaveInk.opacity(0.6))
                Spacer()
            }
            HStack(spacing: 14) {
                metric("documents", counts?.documents)
                metric("groups", counts?.groups)
                metric("entities", counts?.entities)
                metric("relations", counts?.relationships)
                Spacer()
                if let embedder { Pill(text: "embedder · \(embedder.phase.rawValue)", tint: embedder.phase == .ready ? .weaveGreen : .weaveAmber) }
                if let extractor { Pill(text: "extractor · \(extractor)") }
            }
            if needsReseed {
                Text("Its fabric secret is stale (Weave's secret in ~/.rao changed). It is re-seeded at its next start.")
                    .font(.weaveSans(11)).foregroundStyle(Color.weaveAmber)
            }
            if status.isRunning, record.woven, let shape, shape.mothershipGRPCPort == nil {
                Text("Running standalone: start it again to register with the host.").font(.weaveSans(11)).foregroundStyle(Color.weaveInk.opacity(0.5))
            }
        }
    }

    @ViewBuilder private var controls: some View {
        HStack(spacing: 6) {
            if status.isRunning {
                Button("Stop") { send(.stop) }.buttonStyle(WeaveButtonStyle())
                Button("Restart") { send(.restart) }.buttonStyle(WeaveButtonStyle())
            } else {
                Button("Start") { send(.start) }.buttonStyle(WeaveButtonStyle(prominent: true))
            }
            Button(record.woven ? "Weave out" : "Weave in") { send(record.woven ? .weaveOut : .weaveIn) }.buttonStyle(WeaveButtonStyle())
            Button("Explore") { send(.explore) }.buttonStyle(WeaveButtonStyle())
            Menu {
                Button("Make host") { send(.host) }.disabled(isHost)
                Button("Reveal home in Finder") { send(.reveal) }
                Divider()
                Button("Remove…", role: .destructive) { send(.remove) }
            } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
        }
        .disabled(busy)
    }

    private func metric(_ label: String, _ value: Int?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value.map(String.init) ?? "–").font(.weaveSerif(18, weight: .medium))
            Text(label).font(.weaveSans(10.5)).foregroundStyle(Color.weaveInk.opacity(0.5))
        }
    }

    private func send(_ kind: ThreadRowAction.Kind) {
        bubble(.threadRowAction, ThreadRowAction(name: record.name, kind: kind))
    }
}

extension GraniteBubble.Name {
    static let threadRowAction: Self = "ThreadRow.action"
}
