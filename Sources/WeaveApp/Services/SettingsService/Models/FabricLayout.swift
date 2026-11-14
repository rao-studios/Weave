//
//  FabricLayout.swift
//  Weave
//
//  How the Fabric page lays out the spawned AIIs: a grid of cards, a page of `columns` by `rows`
//  at a time, the next page to the right; or a list, one row per AII, its node mark leading.
//

import Foundation

enum FabricLayout: String, Codable, Sendable, CaseIterable {
    case grid, list
}

/// One page of the Fabric's grid: `columns` across, `rows` down. The AIIs past one page continue
/// on the next, to the right.
struct FabricGridSize: Codable, Hashable, Sendable {
    var columns: Int
    var rows: Int

    /// Six to a page: two columns fit the default window, and the page scrolls down to the third row.
    static let standard = FabricGridSize(columns: 2, rows: 3)

    /// The sizes the page offers.
    static let presets: [FabricGridSize] = [
        FabricGridSize(columns: 2, rows: 1), FabricGridSize(columns: 2, rows: 2), .standard, FabricGridSize(columns: 3, rows: 2),
        FabricGridSize(columns: 4, rows: 2), FabricGridSize(columns: 3, rows: 3), FabricGridSize(columns: 4, rows: 3),
    ]

    static let columnRange = 1...6
    static let rowRange = 1...4

    var perPage: Int { columns * rows }
    var label: String { "\(columns) × \(rows)" }

    func clamped() -> FabricGridSize {
        FabricGridSize(columns: min(max(columns, Self.columnRange.lowerBound), Self.columnRange.upperBound),
                       rows: min(max(rows, Self.rowRange.lowerBound), Self.rowRange.upperBound))
    }
}
