//
//  Fabric+View.swift
//  Weave
//

import Granite
import SwiftUI
import WeaveKit

extension Fabric {
    var view: some View {
        let f = fabric.state
        let h = host.state
        let s = settings.state
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(title: "Fabric",
                           subtitle: "\(f.threads.count) spawned AII\(f.threads.count == 1 ? "" : "s") in \(f.root.isEmpty ? s.rootFolder : f.root)") {
                    HStack(spacing: 8) {
                        Button("Rescan") { WeaveAppRoot.shared.rescan() }.buttonStyle(WeaveButtonStyle())
                        Button("Spawn AII") { WeaveAppRoot.shared.showSpawn() }.buttonStyle(WeaveButtonStyle(prominent: true))
                    }
                }

                if f.scanned && !f.serverInstalled {
                    Card {
                        Label("No AIIServer at \(f.serverBinary)", systemImage: "exclamationmark.triangle").font(.weaveSans(12, weight: .semibold))
                            .foregroundStyle(Color.weaveError)
                        Text("Weave runs the AII build installed in ~/.rao. Install it from an AII checkout with `aii install`, or open any Rao app that ships one.")
                            .font(.weaveSans(12)).foregroundStyle(Color.weaveInk.opacity(0.7))
                    }
                }

                HostPicker(state: h, records: f.threads)
                    .onBubble {
                        On(.hostPickerSelect, HostSelection.self) { WeaveAppRoot.shared.selectHost($0) }
                    }

                VStack(alignment: .leading, spacing: 8) {
                    spawnedHeader(count: f.threads.count, s)
                    if f.threads.isEmpty {
                        Card {
                            EmptyState(title: "No AIIs yet",
                                       message: "Spawn one: Weave provisions an AII home in its own folder, gives it its own ports, and starts its Thread with on-device embedding and graph extraction, sharing the models in ~/.rao.")
                        }
                    } else {
                        switch s.fabricLayout {
                        case .grid:
                            FabricGrid(records: f.threads, size: s.fabricGrid, page: $gridPage) { row($0, .card, f, h) }
                        case .list:
                            FabricList(records: f.threads) { row($0, .row, f, h) }
                        }
                    }
                }
                .onChange(of: s.fabricGrid) { gridPage = 0 }
                .onChange(of: s.fabricLayout) { gridPage = 0 }

                ErrorLine(message: f.lastError)
                if let fingerprint = f.fabricFingerprint {
                    Text("Fabric secret \(fingerprint) · probed \(Formatters.ago(f.lastTick))")
                        .font(.weaveMono(10)).foregroundStyle(Color.weaveInk.opacity(0.4))
                }
            }
            .padding(WeaveMetrics.pagePadding)
            .frame(maxWidth: pageWidth(s), alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The caption, and over a fabric with AIIs in it: the grid's page and size, and grid or list.
    private func spawnedHeader(count: Int, _ s: SettingsService.Center.State) -> some View {
        let perPage = s.fabricGrid.perPage
        let pages = (count + perPage - 1) / perPage
        return HStack(alignment: .center, spacing: 10) {
            SectionCaption("Spawned AIIs")
            Spacer(minLength: 0)
            if count > 0 {
                if s.fabricLayout == .grid {
                    if pages > 1 {
                        GridPager(page: min(gridPage ?? 0, pages - 1), pages: pages, perPage: perPage, total: count) { target in
                            withAnimation(.easeInOut(duration: 0.3)) { gridPage = target }
                        }
                    }
                    GridSizePicker(size: settings.binding(\.fabricGrid))
                }
                LayoutToggle(layout: settings.binding(\.fabricLayout))
            }
        }
    }

    private func row(_ record: ThreadRecord, _ style: ThreadRow.Style,
                     _ f: FabricService.Center.State, _ h: HostService.Center.State) -> some View {
        ThreadRow(record: record, status: f.status(of: record.name), embedder: f.embedder[record.name],
                  extractor: f.extractor[record.name], counts: f.counts[record.name], shape: f.shapes[record.name],
                  isHost: h.selection == .spawned(record.name), busy: f.isBusy(record.name),
                  needsReseed: f.reseed.contains(record.name), registered: registered(record, h), style: style)
            .onHover { inside in _state.hovered.wrappedValue = inside ? record.name : nil }
            .onBubble { On(.threadRowAction, ThreadRowAction.self) { perform($0) } }
    }

    /// Wide enough for the grid's columns at their ideal width, and never narrower than the page's own.
    private func pageWidth(_ s: SettingsService.Center.State) -> CGFloat {
        guard s.fabricLayout == .grid else { return Self.maxPageWidth }
        return max(Self.maxPageWidth, FabricGridMetrics.contentWidth(columns: s.fabricGrid.columns) + 2 * WeaveMetrics.pagePadding)
    }

    /// Whether the host sees this Thread as a node right now.
    private func registered(_ record: ThreadRecord, _ host: HostService.Center.State) -> Bool {
        host.nodes.contains { $0.httpPort == record.threadHTTP && $0.isActive }
    }
}
