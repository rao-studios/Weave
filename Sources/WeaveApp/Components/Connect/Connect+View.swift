//
//  Connect+View.swift
//  Weave
//

import Granite
import SwiftUI
import WeaveKit

extension Connect {
    var view: some View {
        let c = connect.state
        let p = port.state
        let thread = ConnectOps.thread(c.thread, records: fabric.state.threads)
        let examples = RequestExamples.all(thread: thread)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageHeader(title: "Connect", subtitle: "File records into an AII and search them from another app, through Weave's port") { EmptyView() }

                Card {
                    SectionCaption("Weave's port")
                    HStack(spacing: 8) {
                        StatusDot(state: p.listening ? .ok : .off, size: 7)
                        Text(verbatim: p.baseURL).font(.weaveMono(12)).textSelection(.enabled)
                        Text(p.listening ? "listening" : "closed: turn it on in Settings").font(.weaveSans(11)).foregroundStyle(Color.weaveInk.opacity(0.5))
                        Spacer(minLength: 0)
                    }
                    Note(p.requireSecret
                         ? "Every /v1 request carries Weave's key in X-Ambient-Secret; the examples read it from ~/.rao/secrets/weave. A sandboxed app cannot read that file: turn off \"Require Weave's secret\" in Settings, or hand the key to it."
                         : "The port asks for no key: any process on this Mac can use it.")
                    LabeledRow("AII") {
                        Picker("AII", selection: Binding(get: { thread }, set: { connect.set(.thread($0)) })) {
                            ForEach(fabric.state.threads) { Text($0.name).tag($0.name) }
                            Text("main AII").tag(ThreadGateway.mainName)
                        }
                    }
                    LabeledRow("Language") {
                        Picker("Language", selection: Binding(get: { c.format }, set: { connect.set(.format($0)) })) {
                            ForEach(RequestFormat.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if let client = RequestExamples.client(format: c.format, port: p.port, requireSecret: p.requireSecret) {
                    Card {
                        HStack(alignment: .firstTextBaseline) {
                            SectionCaption(c.format == .swift ? "The client: WeaveService" : "The client: weave()")
                            Spacer(minLength: 0)
                            copyButton(client, id: "client")
                        }
                        Note(c.format == .swift
                             ? "Drop it into your app as your network service; each call below uses it."
                             : "Save it as weave.mjs and import { weave } from it; each call below uses it.")
                        CodeBlock(code: client, maxHeight: 260)
                    }
                }

                ForEach(examples) { example in
                    ExampleCard(example: example,
                                code: RequestExamples.code(example, format: c.format, port: p.port, requireSecret: p.requireSecret),
                                result: c.results[example.id], running: c.running.contains(example.id),
                                copied: state.copied == example.id)
                        .onBubble {
                            On(.exampleCopy, String.self) { code in copy(code, id: example.id) }
                            On(.exampleRun) { connect.run(example, port: p.port, requireSecret: p.requireSecret) }
                        }
                }
            }
            .padding(WeaveMetrics.pagePadding)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func copyButton(_ code: String, id: String) -> some View {
        Button { copy(code, id: id) } label: {
            Label(state.copied == id ? "Copied" : "Copy", systemImage: state.copied == id ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(WeaveButtonStyle())
    }
}
