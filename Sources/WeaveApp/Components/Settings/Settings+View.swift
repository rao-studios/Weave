//
//  Settings+View.swift
//  Weave
//
//  Every control from the left edge: a label column, then the control at its natural size.
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
                PageHeader(title: "Settings", subtitle: "Where the AIIs live, Weave's port, and how often Weave looks") { EmptyView() }

                Card {
                    SectionCaption("Storage")
                    KeyValueRow(key: "Spawned AIIs", value: FabricRoot.url(s.rootFolder).path)
                    KeyValueRow(key: "On disk", value: f.diskBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "measuring…",
                                mono: false)
                    KeyValueRow(key: "In ~/.rao", value: "Weave's secret and lane only, as every Rao app has", mono: false)
                    Note("Every AII Weave spawns is a full AII home inside Weave's own folder, apart from ~/.rao. Its models are a link to ~/.rao's, so nothing downloads twice and removing an AII never touches them. Any folder on an APFS volume works.")
                    if let legacy = f.legacyNote { Note(legacy).foregroundStyle(Color.weaveAmber) }
                    HStack(spacing: 8) {
                        Button("Reveal in Finder") { WeaveAppRoot.shared.revealRoot() }.buttonStyle(WeaveButtonStyle())
                        Button("Choose Folder…") { WeaveAppRoot.shared.chooseRoot() }.buttonStyle(WeaveButtonStyle())
                        Button("Remove All AIIs…") { WeaveAppRoot.shared.shell.set(.pendingStorage(.removeAll)) }
                            .buttonStyle(WeaveButtonStyle(destructive: true))
                            .disabled(f.threads.isEmpty)
                        Button("Remove Weave from This Mac…") { WeaveAppRoot.shared.shell.set(.pendingStorage(.uninstall)) }
                            .buttonStyle(WeaveButtonStyle(destructive: true))
                        Spacer(minLength: 0)
                    }
                }

                Card {
                    SectionCaption("Weave's port")
                    Toggle("Listen on 127.0.0.1", isOn: settings.binding(\.portEnabled))
                    LabeledRow("Port") {
                        TextField("47600", value: settings.binding(\.port), format: .number.grouping(.never))
                            .textFieldStyle(.roundedBorder).frame(width: 90)
                    }
                    Toggle("Require Weave's secret on /v1/* (X-Ambient-Secret)", isOn: settings.binding(\.requireSecretOnPort))
                    HStack(spacing: 10) {
                        Button("Apply") { WeaveAppRoot.shared.applyPortSettings() }.buttonStyle(WeaveButtonStyle(prominent: true))
                        StatusDot(state: port.state.listening ? .ok : .unknown, size: 7)
                        Text(verbatim: port.state.listening ? "listening on \(port.state.baseURL) · \(port.state.served) served" : "closed")
                            .font(.weaveMono(10.5)).foregroundStyle(Color.weaveInk.opacity(0.6))
                        Spacer(minLength: 0)
                    }
                    ErrorLine(message: port.state.lastError)
                }

                Card {
                    SectionCaption("Spawning")
                    LabeledRow("Graph on ingest") {
                        Picker("Graph on ingest", selection: settings.binding(\.defaultGraphBackend)) {
                            Text("On device").tag("mlx")
                            Text("Keywords only").tag("keyword")
                        }
                    }
                    LabeledRow("At most") {
                        Stepper("\(s.softCap) AIIs", value: settings.binding(\.softCap), in: 1...39)
                        Text("\(s.softCap) AIIs").font(.weaveSans(12))
                    }
                    Note("Each running Thread holds the embedder in memory, and the graph extractor while it reads.")
                    LabeledRow("Federated results") {
                        Stepper("\(s.searchTopK)", value: settings.binding(\.searchTopK), in: 1...50)
                        Text("\(s.searchTopK) partitions").font(.weaveSans(12))
                    }
                    Toggle("Stop the spawned AIIs when Weave quits", isOn: settings.binding(\.stopThreadsOnQuit))
                }

                Card {
                    SectionCaption("Looking")
                    LabeledRow("Probe each Thread") {
                        Stepper("\(Int(s.healthInterval))", value: settings.binding(\.healthInterval), in: 1...60)
                        Text("every \(Int(s.healthInterval)) s").font(.weaveSans(12))
                    }
                    LabeledRow("Read the host's nodes") {
                        Stepper("\(Int(s.hostPollInterval))", value: settings.binding(\.hostPollInterval), in: 1...60)
                        Text("every \(Int(s.hostPollInterval)) s").font(.weaveSans(12))
                    }
                    HStack {
                        Button("Apply") { WeaveAppRoot.shared.applyIntervals() }.buttonStyle(WeaveButtonStyle())
                        Spacer(minLength: 0)
                    }
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task { await fabric.measure() }
    }
}
