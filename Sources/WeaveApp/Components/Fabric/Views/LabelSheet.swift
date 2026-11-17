//
//  LabelSheet.swift
//  Weave
//
//  An AII's label: the name it says on /health, and the name Weave and every app that finds it by its
//  port show. Kept in the AII's home, so `aii label` sees the same one; the handle stays as it is.
//

import Granite
import SwiftUI
import WeaveKit

struct LabelRequest: Sendable, Equatable {
    let name: String
    let label: String
}

/// The instance a Label sheet is open for.
struct LabelTarget: Identifiable, Equatable {
    let name: String
    var id: String { name }
}

struct LabelSheet: View {
    let name: String
    let current: String
    @State private var text = ""
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                WeaveMark(size: 26)
                Text("Label \(name)").font(.weaveSerif(22, weight: .medium, italic: true))
            }
            Note("The AII says its label on /health, so Weave and any app that finds it on this Mac show it by this name. It lives in the AII's home: `aii label` reads and sets the same one. Its handle, \(name), stays.")
            VStack(alignment: .leading, spacing: 6) {
                SectionCaption("Label")
                TextField(name, text: $text).textFieldStyle(.roundedBorder).font(.weaveSans(13)).onSubmit(submit)
                Text(valid || text.isEmpty ? "One line, up to \(AIILabel.maximumLength) characters." : "One line of 1 to \(AIILabel.maximumLength) characters.")
                    .font(.weaveSans(10.5)).foregroundStyle(valid || text.isEmpty ? Color.weaveInk.opacity(0.45) : Color.weaveError)
            }
            HStack {
                Spacer()
                Button("Cancel") { bubble(.labelSheetCancel) }.keyboardShortcut(.cancelAction).buttonStyle(WeaveButtonStyle())
                Button("Label") { submit() }.keyboardShortcut(.defaultAction).buttonStyle(WeaveButtonStyle(prominent: true)).disabled(!valid)
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(Color.weaveBG)
        .onAppear { if text.isEmpty { text = current } }
    }

    private var valid: Bool { AIILabel.normalized(text) != nil }

    private func submit() {
        guard let label = AIILabel.normalized(text) else { return }
        bubble(.labelSheetSubmit, LabelRequest(name: name, label: label))
    }
}

extension GraniteBubble.Name {
    static let labelSheetSubmit: Self = "LabelSheet.submit"
    static let labelSheetCancel: Self = "LabelSheet.cancel"
}
