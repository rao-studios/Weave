//
//  LayoutControls.swift
//  Weave
//
//  The controls over the Fabric's AIIs: grid or list, the grid's size, and, when the AIIs fill more
//  than one page, which page is showing with a step either way.
//

import SwiftUI

/// Grid or list, as the Explorer's panes are chosen: a segmented control.
struct LayoutToggle: View {
    @Binding var layout: FabricLayout

    var body: some View {
        Picker("Layout", selection: $layout) {
            Image(systemName: "square.grid.2x2").accessibilityLabel("Grid").tag(FabricLayout.grid)
            Image(systemName: "list.bullet").accessibilityLabel("List").tag(FabricLayout.list)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .help("Show the AIIs as a grid of cards or as a list")
    }
}

/// Cards to a page, columns by rows.
struct GridSizePicker: View {
    @Binding var size: FabricGridSize

    var body: some View {
        Picker("Grid size", selection: $size) {
            ForEach(options, id: \.self) { Text(verbatim: $0.label).tag($0) }
        }
        .labelsHidden()
        .fixedSize()
        .help("Cards to a page: columns × rows. More AIIs continue on the next page, to the right.")
    }

    /// The presets, and a size a stale file kept that is not one of them.
    private var options: [FabricGridSize] {
        FabricGridSize.presets.contains(size) ? FabricGridSize.presets : FabricGridSize.presets + [size]
    }
}

/// "1–4 of 7" and a step to the previous or next page.
struct GridPager: View {
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int
    let go: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(verbatim: "\(first)–\(last) of \(total)")
                .font(.weaveMono(10.5)).monospacedDigit()
                .foregroundStyle(Color.weaveInk.opacity(0.55))
            step("chevron.left", to: page - 1, label: "Previous page")
            step("chevron.right", to: page + 1, label: "Next page")
        }
    }

    private var first: Int { min(page * perPage + 1, total) }
    private var last: Int { min((page + 1) * perPage, total) }

    private func step(_ symbol: String, to target: Int, label: String) -> some View {
        Button { go(target) } label: {
            Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
        }
        .buttonStyle(WeaveButtonStyle())
        .disabled(!(0..<pages).contains(target))
        .help(label)
        .accessibilityLabel(label)
    }
}
