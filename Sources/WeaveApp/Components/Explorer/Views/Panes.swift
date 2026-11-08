//
//  Panes.swift
//  Weave
//
//  The Explorer's panes. Each takes the Explorer service's state as a value, binds the drafts the
//  page owns, and sends what it does with `bubble`.
//

import Granite
import SwiftUI
import WeaveKit

struct StatsPane: View {
    let state: ExplorerService.Center.State

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if state.isLoading(.stats) && state.stats == nil { ProgressView() }
            ErrorLine(message: state.errors[.stats])
            if let stats = state.stats {
                HStack(spacing: 12) {
                    tile("documents", stats.documents)
                    tile("groups", stats.groups)
                    tile("entities", stats.entities)
                    tile("relationships", stats.relationships)
                }
                Card {
                    SectionCaption("Models")
                    KeyValueRow(key: "Embedder", value: state.embedder.map { "\($0.phase.rawValue) · \($0.model ?? "-") · \($0.vectorSpace ?? "-")" } ?? "unknown")
                    KeyValueRow(key: "Extractor", value: state.extractor ?? "unknown")
                    KeyValueRow(key: "Lane", value: stats.lane.description)
                }
                if !stats.topEntities.isEmpty {
                    Card {
                        SectionCaption("Most mentioned")
                        ForEach(stats.topEntities, id: \.id) { entity in
                            HStack {
                                Text(entity.name).font(.weaveSans(12.5))
                                Pill(text: entity.kind)
                                Spacer()
                                Text("\(entity.mentionCount)").font(.weaveMono(11))
                            }
                        }
                    }
                }
            }
        }
    }

    private func tile(_ label: String, _ value: Int) -> some View {
        Card {
            Text("\(value)").font(.weaveSerif(30, weight: .medium))
            Text(label).font(.weaveSans(11)).foregroundStyle(Color.weaveInk.opacity(0.5))
        }
        .frame(maxWidth: 180)
    }
}

struct LibraryPane: View {
    let state: ExplorerService.Center.State

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if state.isLoading(.library) { ProgressView() }
            ErrorLine(message: state.errors[.library])
            if state.library.isEmpty && !state.isLoading(.library) {
                Text("Nothing filed in Weave's lane here yet. Deposit something.").font(.weaveSans(12)).foregroundStyle(Color.weaveInk.opacity(0.5))
            }
            ForEach(state.library) { group in
                Card {
                    HStack {
                        Text(group.label).font(.weaveSerif(15, weight: .medium, italic: true))
                        Pill(text: group.ownerId)
                        Spacer()
                        Text("\(group.documents.count) documents").font(.weaveSans(11)).foregroundStyle(Color.weaveInk.opacity(0.5))
                    }
                    ForEach(group.documents.prefix(50)) { document in
                        HStack {
                            Text(document.name ?? document.id).font(.weaveMono(11)).lineLimit(1).textSelection(.enabled)
                            Spacer()
                            if let date = document.createdAt { Text(date, style: .date).font(.weaveSans(10.5)).foregroundStyle(Color.weaveInk.opacity(0.45)) }
                        }
                    }
                }
            }
        }
    }
}

struct GraphPane: View {
    let state: ExplorerService.Center.State
    @Binding var entity: String
    @Binding var query: String
    @Binding var hops: Int
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("Entity (blank: browse)", text: $entity).textFieldStyle(.roundedBorder).frame(width: 200)
                TextField("or a query", text: $query).textFieldStyle(.roundedBorder).frame(width: 220)
                Stepper("hops \(hops)", value: $hops, in: 1...3).font(.weaveSans(11.5))
                Button("Walk") { bubble(.graphPaneLoad) }.buttonStyle(WeaveButtonStyle(prominent: true))
                if state.isLoading(.graph) { ProgressView().controlSize(.small) }
            }
            ErrorLine(message: state.errors[.graph])
            if let graph = state.graph {
                Text("\(graph.stats?.entityCount ?? graph.entities.count) entities · \(graph.stats?.relationshipCount ?? graph.relationships.count) relationships in the lane")
                    .font(.weaveSans(11)).foregroundStyle(Color.weaveInk.opacity(0.5))
                HStack(alignment: .top, spacing: 12) {
                    Card {
                        SectionCaption("Entities")
                        ForEach(graph.entities.prefix(60)) { e in
                            HStack {
                                Text(e.name).font(.weaveSans(12))
                                Pill(text: e.kind)
                                Spacer()
                                Text("\(e.mentionCount)").font(.weaveMono(10.5)).foregroundStyle(Color.weaveInk.opacity(0.5))
                            }
                        }
                    }
                    Card {
                        SectionCaption("Relationships")
                        ForEach(graph.relationships.prefix(60)) { r in
                            HStack(spacing: 6) {
                                Text(graph.name(of: r.subjectId)).font(.weaveSans(12))
                                Text(r.predicate).font(.weaveMono(10.5)).foregroundStyle(Color.weaveAccent)
                                Text(graph.name(of: r.objectId)).font(.weaveSans(12))
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ThreadSearchPane: View {
    let state: ExplorerService.Center.State
    @Binding var query: String
    @Binding var topK: Int
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("Search this Thread alone", text: $query).textFieldStyle(.roundedBorder).onSubmit { bubble(.threadSearchRun) }
                Stepper("top \(topK)", value: $topK, in: 1...50).font(.weaveSans(11.5)).frame(width: 110)
                Button("Search") { bubble(.threadSearchRun) }.buttonStyle(WeaveButtonStyle(prominent: true))
                if state.isLoading(.search) { ProgressView().controlSize(.small) }
            }
            ErrorLine(message: state.errors[.search])
            ForEach(state.hits) { hit in
                Card {
                    HStack {
                        Text("#\(hit.rank)").font(.weaveMono(11)).foregroundStyle(Color.weaveAccent)
                        Spacer()
                        Text(verbatim: "document \(hit.reference.id.prefix(8))…").font(.weaveMono(9.5)).foregroundStyle(Color.weaveInk.opacity(0.35))
                            .help(hit.reference.id)
                        Pill(text: hit.reference.ownerId)
                    }
                    Text(hit.text).font(.weaveSans(12.5)).textSelection(.enabled)
                }
            }
        }
    }
}

struct DepositPane: View {
    let state: ExplorerService.Center.State
    let ref: ThreadRef
    @Binding var text: String
    @Binding var name: String
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        let group = ExplorerOps.depositGroup(ref)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Filed into \(group.label) as \(WeaveIdentity.owner), the owner the host's federated search answers for. The Thread embeds it on device and extracts its graph.")
                .font(.weaveSans(12)).foregroundStyle(Color.weaveInk.opacity(0.6))
            TextField("Name (optional)", text: $name).textFieldStyle(.roundedBorder).frame(maxWidth: 360)
            TextEditor(text: $text)
                .font(.weaveSans(13))
                .frame(minHeight: 200)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.8)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.weaveBorder))
            HStack {
                Button("Deposit") { bubble(.depositPaneSubmit) }
                    .buttonStyle(WeaveButtonStyle(prominent: true))
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.isLoading(.deposit))
                if state.isLoading(.deposit) { ProgressView().controlSize(.small) }
                Spacer()
            }
            ErrorLine(message: state.errors[.deposit])
            if let receipt = state.lastDeposit {
                Label(receipt, systemImage: "checkmark.circle").font(.weaveSans(12)).foregroundStyle(Color.weaveGreen)
            }
        }
    }
}

struct LogPane: View {
    let state: ExplorerService.Center.State
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button("Reload") { bubble(.logPaneReload) }.buttonStyle(WeaveButtonStyle())
                if state.isLoading(.log) { ProgressView().controlSize(.small) }
                Spacer()
            }
            ErrorLine(message: state.errors[.log])
            Text(state.log.isEmpty ? "Reload to read the Thread's log." : state.log.joined(separator: "\n"))
                .font(.weaveMono(10.5))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.weaveInk.opacity(0.04)))
        }
    }
}

extension GraniteBubble.Name {
    static let graphPaneLoad: Self = "GraphPane.load"
    static let threadSearchRun: Self = "ThreadSearchPane.run"
    static let depositPaneSubmit: Self = "DepositPane.submit"
    static let logPaneReload: Self = "LogPane.reload"
}
