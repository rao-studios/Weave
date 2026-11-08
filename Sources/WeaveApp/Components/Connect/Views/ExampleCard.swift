//
//  ExampleCard.swift
//  Weave
//
//  One request: what it does, its method and path, its code to copy, and its answer when run here.
//

import Granite
import SwiftUI
import WeaveKit

struct ExampleCard: View {
    let example: RequestExample
    let code: String
    let direct: String?
    let result: ConnectOps.Result?
    let running: Bool
    let copied: Bool
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        Card {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(example.title).font(.weaveSerif(16, weight: .medium, italic: true)).foregroundStyle(Color.weaveInk)
                Pill(text: example.method, tint: example.method == "GET" ? .weaveBlue : .weaveAccent)
                Text(verbatim: example.path).font(.weaveMono(11)).foregroundStyle(Color.weaveInk.opacity(0.6))
                Spacer(minLength: 0)
                Button { bubble(.exampleCopy, code) } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(WeaveButtonStyle())
                Button { bubble(.exampleRun) } label: { Label("Run", systemImage: "play.fill") }
                    .buttonStyle(WeaveButtonStyle(prominent: true))
                    .disabled(running)
            }
            Note(example.detail)
            CodeBlock(code: code, maxHeight: 200)
            if let direct {
                Label(direct, systemImage: "arrow.turn.down.right")
                    .font(.weaveSans(11)).foregroundStyle(Color.weaveInk.opacity(0.5))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if running {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Asking Weave's port…").font(.weaveSans(11)) }
            } else if let result {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        StatusDot(state: result.ok ? .ok : .off, size: 7)
                        Text(verbatim: result.status == 0 ? "no answer" : "HTTP \(result.status)").font(.weaveMono(11))
                        Text(Formatters.ms(result.milliseconds)).font(.weaveMono(10.5)).foregroundStyle(Color.weaveInk.opacity(0.45))
                        Spacer(minLength: 0)
                    }
                    CodeBlock(code: result.body, maxHeight: 220, tint: result.ok ? .weaveGreen : .weaveError)
                }
            }
        }
    }
}

/// Code, monospaced, selectable, set from the left; long lines wrap, a long block scrolls.
struct CodeBlock: View {
    let code: String
    var maxHeight: CGFloat = 220
    var tint: Color = .weaveInk

    var body: some View {
        ScrollView(.vertical) {
            Text(verbatim: code)
                .font(.weaveMono(11))
                .foregroundStyle(Color.weaveInk.opacity(0.85))
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .frame(maxHeight: maxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .background(RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(tint.opacity(0.12)))
    }
}

extension GraniteBubble.Name {
    static let exampleCopy: Self = "ExampleCard.copy"
    static let exampleRun: Self = "ExampleCard.run"
}
