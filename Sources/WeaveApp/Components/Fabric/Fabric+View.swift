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
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(title: "Fabric",
                           subtitle: "\(f.threads.count) spawned AII\(f.threads.count == 1 ? "" : "s") in \(f.root.isEmpty ? settings.state.rootFolder : f.root)") {
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
                    SectionCaption("Spawned AIIs")
                    if f.threads.isEmpty {
                        Card {
                            EmptyState(title: "No AIIs yet",
                                       message: "Spawn one: Weave provisions an AII home in its own folder, gives it its own ports, and starts its Thread with on-device embedding and graph extraction, sharing the models in ~/.rao.")
                        }
                    }
                    ForEach(f.threads) { record in
                        ThreadRow(record: record, status: f.status(of: record.name), embedder: f.embedder[record.name],
                                  extractor: f.extractor[record.name], counts: f.counts[record.name], shape: f.shapes[record.name],
                                  isHost: h.selection == .spawned(record.name), busy: f.isBusy(record.name),
                                  needsReseed: f.reseed.contains(record.name), registered: registered(record, h))
                            .onHover { inside in _state.hovered.wrappedValue = inside ? record.name : nil }
                            .onBubble { On(.threadRowAction, ThreadRowAction.self) { perform($0) } }
                    }
                }

                ErrorLine(message: f.lastError)
                if let fingerprint = f.fabricFingerprint {
                    Text("Fabric secret \(fingerprint) · probed \(Formatters.ago(f.lastTick))")
                        .font(.weaveMono(10)).foregroundStyle(Color.weaveInk.opacity(0.4))
                }
            }
            .padding(WeaveMetrics.pagePadding)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Whether the host sees this Thread as a node right now.
    private func registered(_ record: ThreadRecord, _ host: HostService.Center.State) -> Bool {
        host.nodes.contains { $0.httpPort == record.threadHTTP && $0.isActive }
    }
}
