//
//  ThreadPicker.swift
//  Weave
//

import Granite
import SwiftUI
import WeaveKit

struct ThreadPicker: View {
    let selected: ThreadRef?
    let records: [ThreadRecord]
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        Picker("Thread", selection: Binding(get: { selected ?? .main }, set: { bubble(.threadPickerSelect, $0) })) {
            Text("main AII").tag(ThreadRef.main)
            ForEach(records) { Text($0.name).tag(ThreadRef.spawned($0.name)) }
        }
        .labelsHidden()
        .fixedSize()
    }
}

extension GraniteBubble.Name {
    static let threadPickerSelect: Self = "ThreadPicker.select"
}
