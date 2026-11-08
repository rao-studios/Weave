//
//  Settings+View.swift
//  Weave
//

import Granite
import SwiftUI
import WeaveKit

extension Settings {
    var view: some View {
        let s = settings.state
        let f = fabric.state
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageHeader(title: "Settings", subtitle: "Where the fabric lives, Weave's port, and how often Weave looks") { EmptyView() }

                Card {
                    SectionCaption("Folder")
                    KeyValueRow(key: "Spawned AIIs", value: FabricRoot.url(s.rootFolder).path)
                    Text("Any folder on an APFS volume; ~/.rao/weave by default. Each AII is a full AII home inside it, with its models linked to ~/.rao's.")
                        .font(.weaveSans(11.5)).foregroundStyle(Color.weaveInk.opacity(0.55))
                    HStack {
                        Button("Choose Folder…") { WeaveAppRoot.shared.chooseRoot() }.buttonStyle(WeaveButtonStyle())
                        Button("Reveal in Finder") { WeaveAppRoot.shared.revealRoot() }.buttonStyle(WeaveButtonStyle())
                    }
                }

                Card {
                    SectionCaption("Weave's port")
                    Toggle("Listen on 127.0.0.1", isOn: settings.binding(\.portEnabled))
                    HStack {
                        Text("Port").font(.weaveSans(12))
                        TextField("47600", value: settings.binding(\.port), format: .number.grouping(.never)).textFieldStyle(.roundedBorder).frame(width: 90)
                    }
                    Toggle("Require Weave's secret on /v1/* (X-Ambient-Secret)", isOn: settings.binding(\.requireSecretOnPort))
                    HStack {
                        Button("Apply") { WeaveAppRoot.shared.applyPortSettings() }.buttonStyle(WeaveButtonStyle(prominent: true))
                        StatusDot(state: port.state.listening ? .ok : .unknown, size: 7)
                        Text(port.state.listening ? "listening on \(port.state.baseURL) · \(port.state.served) served" : "closed")
                            .font(.weaveMono(10.5)).foregroundStyle(Color.weaveInk.opacity(0.6))
                    }
                    ErrorLine(message: port.state.lastError)
                }

                Card {
                    SectionCaption("Spawning")
                    Picker("Graph on ingest", selection: settings.binding(\.defaultGraphBackend)) {
                        Text("On device").tag("mlx")
                        Text("Keywords only").tag("keyword")
                    }
                    .frame(maxWidth: 320)
                    Stepper("At most \(s.softCap) AIIs", value: settings.binding(\.softCap), in: 1...39)
                    Text("Each running Thread holds the embedder in memory, and the graph extractor while it reads.")
                        .font(.weaveSans(11.5)).foregroundStyle(Color.weaveInk.opacity(0.55))
                    Stepper("Federated results: \(s.searchTopK)", value: settings.binding(\.searchTopK), in: 1...50)
                    Toggle("Stop the spawned AIIs when Weave quits", isOn: settings.binding(\.stopThreadsOnQuit))
                }

                Card {
                    SectionCaption("Looking")
                    Stepper("Probe every Thread every \(Int(s.healthInterval)) s", value: settings.binding(\.healthInterval), in: 1...60)
                    Stepper("Read the host's nodes every \(Int(s.hostPollInterval)) s", value: settings.binding(\.hostPollInterval), in: 1...60)
                    Button("Apply") { WeaveAppRoot.shared.applyIntervals() }.buttonStyle(WeaveButtonStyle())
                }

                Card {
                    SectionCaption("The AII")
                    KeyValueRow(key: "AIIServer", value: f.serverBinary.isEmpty ? "–" : f.serverBinary)
                    KeyValueRow(key: "Installed", value: f.serverInstalled ? "yes" : "no: run `aii install` from an AII checkout", mono: false)
                    KeyValueRow(key: "Fabric secret", value: f.fabricFingerprint ?? "–")
                    KeyValueRow(key: "Owner", value: WeaveIdentity.owner)
                }
            }
            .padding(WeaveMetrics.pagePadding)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }
}
