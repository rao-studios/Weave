//
//  SearchViews.swift
//  Weave
//

import SwiftUI
import WeaveKit

/// The nodes the host fans out to, named by Weave instance.
struct PartitionLegend: View {
    let state: HostService.Center.State
    let records: [ThreadRecord]

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(state: StatusDot.State(state.sewn), size: 7)
            Text("host \(state.selection.description)").font(.weaveSans(11)).foregroundStyle(Color.weaveInk.opacity(0.6))
            if state.nodes.isEmpty {
                Text("· no nodes registered yet").font(.weaveSans(11)).foregroundStyle(Color.weaveInk.opacity(0.45))
            } else {
                Text("· fans out to").font(.weaveSans(11)).foregroundStyle(Color.weaveInk.opacity(0.45))
                ForEach(state.nodes.filter(\.isActive)) { node in
                    Pill(text: HostOps.name(of: node, records: records, mainThreadHTTP: SearchOps.mainThreadHTTP()) ?? (node.app ?? "node"),
                         tint: .weaveAccent)
                }
            }
            Spacer()
        }
    }
}

struct ResultRow: View {
    let hit: SearchHit

    var body: some View {
        Card {
            HStack(spacing: 8) {
                Text("#\(hit.rank)").font(.weaveMono(11)).foregroundStyle(Color.weaveAccent)
                if let name = hit.threadName { Pill(text: name, tint: .weaveBlue) } else { Pill(text: hit.reference.threadId.map { String($0.prefix(8)) } ?? "?") }
                Text(hit.reference.id).font(.weaveMono(10)).foregroundStyle(Color.weaveInk.opacity(0.45)).lineLimit(1)
                Spacer()
            }
            Text(hit.text).font(.weaveSans(12.5)).textSelection(.enabled)
        }
    }
}
