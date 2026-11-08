//
//  Explorer+View.swift
//  Weave
//

import Granite
import SwiftUI
import WeaveKit

extension Explorer {
    var view: some View {
        let e = explorer.state
        return VStack(alignment: .leading, spacing: 14) {
            PageHeader(title: "Explorer", subtitle: subtitle) {
                ThreadPicker(selected: shell.state.selectedThread, records: fabric.state.threads)
                    .onBubble { On(.threadPickerSelect, ThreadRef.self) { WeaveAppRoot.shared.explore($0) } }
            }
            if let ref = e.selected {
                Picker("Pane", selection: center.$state.binding.tab) {
                    ForEach(Pane.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .leading)
                ScrollView {
                    pane(state.tab, ref: ref, e)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Card {
                    EmptyState(title: "Choose a Thread",
                               message: "Pick the main AII or a spawned one above, or click one in the sidebar. Weave reads it with its own secret, so you see what Weave filed there and nothing of another app's.")
                }
                .frame(maxWidth: 760, alignment: .leading)
                Spacer(minLength: 0)
            }
        }
        .padding(WeaveMetrics.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: state.tab) { _, tab in load(tab) }
    }

    private var subtitle: String {
        guard let ref = explorer.state.selected else { return "One Thread at a time, in Weave's lane" }
        switch ref {
        case .main: return "The main AII's Thread, Weave's lane"
        case .spawned(let name):
            guard let record = fabric.state.record(name) else { return name }
            return "\(name) · http \(record.threadHTTP) · grpc \(record.threadGRPC) · \(record.home)"
        }
    }

    @ViewBuilder
    private func pane(_ tab: Pane, ref: ThreadRef, _ e: ExplorerService.Center.State) -> some View {
        switch tab {
        case .stats: StatsPane(state: e)
        case .library: LibraryPane(state: e)
        case .graph:
            GraphPane(state: e, entity: center.$state.binding.entityDraft, query: center.$state.binding.graphQueryDraft,
                      hops: center.$state.binding.hops)
                .onBubble { On(.graphPaneLoad) { load(.graph) } }
        case .search:
            ThreadSearchPane(state: e, query: center.$state.binding.queryDraft, topK: center.$state.binding.topK)
                .onBubble { On(.threadSearchRun) { load(.search) } }
        case .deposit:
            DepositPane(state: e, ref: ref, text: center.$state.binding.depositDraft, name: center.$state.binding.depositName)
                .onBubble { On(.depositPaneSubmit) { deposit(ref) } }
        case .log:
            LogPane(state: e).onBubble { On(.logPaneReload) { load(.log) } }
        }
    }
}
