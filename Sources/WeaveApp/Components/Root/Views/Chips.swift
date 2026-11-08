//
//  Chips.swift
//  Weave
//
//  The toolbar's two readings: the host (which AII, its Sewn's state, how many nodes it sees) and
//  Weave's own port.
//

import SwiftUI
import WeaveKit

struct HostChip: View {
    let state: HostService.Center.State

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(state: state.isSwitching ? .warn : StatusDot.State(state.sewn), size: 7)
            Text("host").font(.weaveSans(10.5)).foregroundStyle(Color.weaveInk.opacity(0.5))
            Text(state.selection.description).font(.weaveSans(11, weight: .medium))
            if let target = state.target {
                Text(verbatim: ":\(target.sewnPorts.http)").font(.weaveMono(10)).foregroundStyle(Color.weaveInk.opacity(0.5))
            }
            if !state.nodes.isEmpty {
                Pill(text: "\(state.nodes.filter(\.isActive).count) nodes", tint: .weaveAccent)
            }
        }
        .padding(.horizontal, 6)
        .fixedSize()
        .help(state.lastError ?? "The Sewn the woven Threads register with; its /v1/search fans out across them.")
    }
}

struct PortChip: View {
    let state: PortService.Center.State

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(state: state.listening ? .ok : (state.enabled ? .off : .unknown), size: 7)
            Text(verbatim: ":\(state.port)").font(.weaveMono(10.5))
        }
        .padding(.horizontal, 6)
        .help(state.lastError ?? (state.listening ? "Weave's port: \(state.baseURL)" : "Weave's port is closed"))
    }
}
