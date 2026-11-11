//
//  SpawnSheet.swift
//  Weave
//
//  A new AII: its name (a lowercase handle) and how its Thread extracts a graph on ingest.
//

import Granite
import SwiftUI
import WeaveKit

struct SpawnRequest: Sendable, Equatable {
    let name: String
    let graphBackend: String
}

struct SpawnSheet: View {
    let defaultBackend: String
    let root: String
    @State private var name = ""
    @State private var backend = ""
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                WeaveMark(size: 26)
                Text("Spawn an AII").font(.weaveSerif(22, weight: .medium, italic: true))
            }
            Note("A new AII home in Weave's folder: its own Thread on its own ports, embedding with voyage-4-nano and sharing the models already in ~/.rao. It starts woven into the host.")
            VStack(alignment: .leading, spacing: 6) {
                SectionCaption("Name")
                TextField("alpha", text: $name).textFieldStyle(.roundedBorder).font(.weaveMono(13)).onSubmit(submit)
                Text(valid || name.isEmpty ? "Lowercase letters, digits and single hyphens, starting with a letter." : "Lowercase letters, digits and single hyphens, starting with a letter, 2–32 long, and not main, models or aii.")
                    .font(.weaveSans(10.5)).foregroundStyle(valid || name.isEmpty ? Color.weaveInk.opacity(0.45) : Color.weaveError)
            }
            VStack(alignment: .leading, spacing: 6) {
                SectionCaption("Graph on ingest")
                Picker("Graph", selection: $backend) {
                    Text("On device (granite-4.0-h-micro)").tag("mlx")
                    Text("Keywords only").tag("keyword")
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
            HStack {
                Spacer()
                Button("Cancel") { bubble(.spawnSheetCancel) }.keyboardShortcut(.cancelAction).buttonStyle(WeaveButtonStyle())
                Button("Spawn") { submit() }.keyboardShortcut(.defaultAction).buttonStyle(WeaveButtonStyle(prominent: true)).disabled(!valid)
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(Color.weaveBG)
        .onAppear { if backend.isEmpty { backend = defaultBackend } }
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces).lowercased() }
    private var valid: Bool { ThreadRecord.isValidName(trimmed) }

    private func submit() {
        guard valid else { return }
        bubble(.spawnSheetSubmit, SpawnRequest(name: trimmed, graphBackend: backend.isEmpty ? defaultBackend : backend))
    }
}

extension GraniteBubble.Name {
    static let spawnSheetSubmit: Self = "SpawnSheet.submit"
    static let spawnSheetCancel: Self = "SpawnSheet.cancel"
}
