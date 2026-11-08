//
//  Explorer+Actions.swift
//  Weave
//

import SwiftUI
import WeaveKit

extension Explorer {
    /// Reads `tab`'s data for the selected Thread.
    func load(_ tab: Pane) {
        guard let ref = explorer.state.selected else { return }
        let explorer = self.explorer
        let request: ExplorerService.Request
        switch tab {
        case .stats: request = .stats
        case .library: request = .library
        case .graph:
            request = .graph(entity: state.entityDraft.trimmingCharacters(in: .whitespaces),
                             query: state.graphQueryDraft.trimmingCharacters(in: .whitespaces), hops: state.hops)
        case .search:
            let query = state.queryDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return }
            request = .search(query: query, topK: state.topK)
        case .deposit: return
        case .log: request = .log
        }
        Task { await explorer.load(request, on: ref) }
    }

    /// Files the draft into the Thread; on success the draft clears and the counts are read again.
    func deposit(_ ref: ThreadRef) {
        let text = state.depositDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let name = state.depositName.trimmingCharacters(in: .whitespaces)
        let explorer = self.explorer
        let draft = _state.depositDraft
        Task {
            if await explorer.load(.deposit(text: text, name: name.isEmpty ? nil : name), on: ref) {
                await MainActor.run { draft.wrappedValue = "" }
                await explorer.refresh(ref)
            }
        }
    }
}
