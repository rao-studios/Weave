//
//  HostPicker.swift
//  Weave
//
//  The host: which AII's Sewn the woven Threads register with, its state, and the nodes it fans a
//  search out to. Choosing another restarts the running woven Threads onto it.
//

import Granite
import SwiftUI
import WeaveKit

struct HostPicker: View {
    let state: HostService.Center.State
    let records: [ThreadRecord]
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        Card {
            HStack(alignment: .firstTextBaseline) {
                SectionCaption("Host")
                Spacer()
                if state.isSwitching { ProgressView().controlSize(.small) }
            }
            HStack(spacing: 12) {
                Picker("Host", selection: Binding(get: { state.selection }, set: { choose($0) })) {
                    Text("main AII (~/.rao)").tag(HostSelection.main)
                    ForEach(records) { record in Text(record.name).tag(HostSelection.spawned(record.name)) }
                }
                .labelsHidden()
                .frame(width: 220)
                .disabled(state.isSwitching)
                StatusDot(state: state.isSwitching ? .warn : StatusDot.State(state.sewn))
                if let target = state.target {
                    Text(verbatim: "Sewn http \(target.sewnPorts.http) · grpc \(target.sewnPorts.grpc)").font(.weaveMono(11))
                }
                Spacer()
                if let phase = state.mainPhase, state.selection == .main {
                    Pill(text: phase)
                }
            }
            Text(caption).font(.weaveSans(11.5)).foregroundStyle(Color.weaveInk.opacity(0.6))
            if !state.nodes.filter(\.isActive).isEmpty {
                HStack(spacing: 6) {
                    Text("Nodes").font(.weaveSans(11)).foregroundStyle(Color.weaveInk.opacity(0.5))
                    ForEach(state.nodes.filter(\.isActive)) { node in
                        Pill(text: (HostOps.name(of: node, records: records, mainThreadHTTP: SearchOps.mainThreadHTTP()) ?? node.app ?? "?")
                             + " :\(node.httpPort)", tint: node.isActive ? .weaveAccent : .weaveInk)
                    }
                }
            }
            if !state.rewoven.isEmpty {
                Text("Moved onto this host: \(state.rewoven.joined(separator: ", "))").font(.weaveSans(11)).foregroundStyle(Color.weaveInk.opacity(0.5))
            }
            ErrorLine(message: state.lastError)
        }
    }

    private var caption: String {
        switch state.selection {
        case .main:
            return "The main AII's Sewn hosts. Woven Threads register as Weave's nodes, which Ambient, Craft and Veil never search or file into; Weave's search also reaches what Weave filed in the main Thread."
        case .spawned(let name):
            return "\(name) runs a Sewn of its own on its slot's ports, and every woven Thread, \(name)'s included, registers with it."
        }
    }

    private func choose(_ selection: HostSelection) {
        guard selection != state.selection else { return }
        bubble(.hostPickerSelect, selection)
    }
}

extension GraniteBubble.Name {
    static let hostPickerSelect: Self = "HostPicker.select"
}
