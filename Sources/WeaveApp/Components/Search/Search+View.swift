//
//  Search+View.swift
//  Weave
//

import Granite
import SwiftUI
import WeaveKit

extension Search {
    var view: some View {
        let s = search.state
        let h = host.state
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageHeader(title: "Search", subtitle: "One query, every woven Thread, merged by the host") { EmptyView() }

                Card {
                    HStack(spacing: 8) {
                        TextField("Ask every Thread woven into \(h.selection.description)", text: center.$state.binding.draft)
                            .textFieldStyle(.roundedBorder)
                            .font(.weaveSans(13.5))
                            .onSubmit(run)
                        Button("Search") { run() }
                            .buttonStyle(WeaveButtonStyle(prominent: true))
                            .disabled(state.draft.trimmingCharacters(in: .whitespaces).isEmpty || s.searching || h.target == nil)
                        if s.searching { ProgressView().controlSize(.small) }
                    }
                    PartitionLegend(state: h, records: fabric.state.threads)
                }

                ErrorLine(message: s.lastError)

                if !s.hits.isEmpty {
                    HStack(spacing: 8) {
                        Text("\(s.hits.count) partitions").font(.weaveSans(12, weight: .semibold))
                        if !s.answeredBy.isEmpty { Text("from " + s.answeredBy.joined(separator: ", ")).font(.weaveSans(12)).foregroundStyle(Color.weaveInk.opacity(0.6)) }
                        Spacer()
                        if let latency = s.latencyMs { Text(Formatters.ms(latency)).font(.weaveMono(11)).foregroundStyle(Color.weaveInk.opacity(0.5)) }
                    }
                    ForEach(s.hits) { hit in ResultRow(hit: hit) }
                    if let graph = s.graph, !graph.matchedEntityIds.isEmpty {
                        Text("The graph matched \(graph.matchedEntityIds.count) entities and expanded \(graph.expandedDocuments) documents.")
                            .font(.weaveSans(11)).foregroundStyle(Color.weaveInk.opacity(0.5))
                    }
                } else if !s.query.isEmpty && !s.searching && s.lastError == nil {
                    Text("Nothing in any woven Thread matched “\(s.query)”. Deposits must be filed as \(WeaveIdentity.owner) for the host to find them.")
                        .font(.weaveSans(12)).foregroundStyle(Color.weaveInk.opacity(0.55))
                }

                Card {
                    SectionCaption("From another process")
                    Text("Weave's port forwards the same search to the host:").font(.weaveSans(12)).foregroundStyle(Color.weaveInk.opacity(0.6))
                    Text(curl).font(.weaveMono(10.5)).textSelection(.enabled)
                        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.weaveInk.opacity(0.04)))
                }
            }
            .padding(WeaveMetrics.pagePadding)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private var curl: String {
        let secret = port.state.requireSecret ? " \\\n  -H \"X-Ambient-Secret: $(cat ~/.rao/secrets/weave)\"" : ""
        return "curl -s -X POST \(port.state.baseURL)/v1/search\(secret) \\\n  -H 'Content-Type: application/json' \\\n  -d '{\"query\": \"…\", \"top_k\": \(settings.state.searchTopK)}'"
    }

    private func run() {
        let text = state.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let search = self.search, topK = settings.state.searchTopK
        Task { try? await search.query(text, topK: topK) }
    }
}
