//
//  FabricGrid.swift
//  Weave
//
//  The Fabric's cards as pages of `columns` by `rows`, side by side in a horizontal scroll. The
//  columns share the width a page has but never go narrower than a card reads at: when they do not
//  fit, a page is wider than the view and scrolls within itself instead of squeezing its cards.
//  A scroll comes to rest on a page's leading edge, or a column's when a page is wider than the view.
//

import SwiftUI
import WeaveKit

/// The grid's geometry for one viewport width. Pure, so the scroll's resting points, the cells'
/// widths and the page's width all come from one place.
struct FabricGridMetrics: Equatable {
    /// The narrowest a card reads at: its pills, its four counts and its buttons on one line each.
    static let minCellWidth: CGFloat = 340
    /// The widest a column grows on a wide window before the page stops widening.
    static let idealCellWidth: CGFloat = 460
    static let cellMinHeight: CGFloat = 278
    static let spacing: CGFloat = 14
    /// Between pages: wider than between cards, so a page's edge shows while scrolling.
    static let pageGap: CGFloat = 28

    let viewport: CGFloat
    let columns: Int
    /// One card's width.
    let cell: CGFloat
    /// One page's width: the viewport's when the columns fit it, wider when they would not.
    let page: CGFloat

    init(viewport: CGFloat, columns: Int) {
        let columns = max(1, columns)
        let gaps = Self.spacing * CGFloat(columns - 1)
        let share = ((viewport - gaps) / CGFloat(columns)).rounded(.down)
        self.viewport = viewport
        self.columns = columns
        cell = max(Self.minCellWidth, share)
        page = max(viewport, cell * CGFloat(columns) + gaps)
    }

    var stride: CGFloat { page + Self.pageGap }
    var pageFits: Bool { page <= viewport + 0.5 }

    /// Where a horizontal scroll may rest: each page's leading edge when a page fits the view, else
    /// each column's, so no card rests cut at the leading edge.
    func stops(pages: Int) -> [CGFloat] {
        (0..<max(pages, 0)).flatMap { index -> [CGFloat] in
            let start = CGFloat(index) * stride
            guard !pageFits else { return [start] }
            return (0..<columns).map { start + CGFloat($0) * (cell + Self.spacing) }
        }
    }

    /// The width the page grows to for `columns`, so a wide window shows every column at its ideal width.
    static func contentWidth(columns: Int) -> CGFloat {
        let columns = max(1, columns)
        return idealCellWidth * CGFloat(columns) + spacing * CGFloat(columns - 1)
    }

    /// `items` in order, `size` at a time; the last chunk holds what is left.
    static func chunk<T>(_ items: [T], _ size: Int) -> [[T]] {
        let size = max(1, size)
        return Swift.stride(from: 0, to: items.count, by: size).map { Array(items[$0..<min($0 + size, items.count)]) }
    }
}

struct FabricGrid<Cell: View>: View {
    let records: [ThreadRecord]
    let size: FabricGridSize
    /// The page at the leading edge; set it to scroll there.
    @Binding var page: Int?
    @ViewBuilder let cell: (ThreadRecord) -> Cell

    var body: some View {
        let pages = FabricGridMetrics.chunk(records, size.perPage)
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: FabricGridMetrics.pageGap) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, items in
                    pageView(items).id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $page, anchor: .leading)
        .scrollTargetBehavior(FabricGridSnap(columns: size.columns, pages: pages.count))
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    /// One page: a Grid, so the cards in a row share the tallest one's height. A short last page
    /// keeps the full width, so every page can rest at the leading edge.
    private func pageView(_ items: [ThreadRecord]) -> some View {
        let columns = size.columns
        return Grid(alignment: .topLeading, horizontalSpacing: FabricGridMetrics.spacing, verticalSpacing: FabricGridMetrics.spacing) {
            ForEach(Array(FabricGridMetrics.chunk(items, columns).enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(row) { record in
                        cell(record)
                            .frame(minHeight: FabricGridMetrics.cellMinHeight, alignment: .top)
                            .containerRelativeFrame(.horizontal, alignment: .topLeading) { length, _ in
                                FabricGridMetrics(viewport: length, columns: columns).cell
                            }
                    }
                }
            }
        }
        .containerRelativeFrame(.horizontal, alignment: .topLeading) { length, _ in
            FabricGridMetrics(viewport: length, columns: columns).page
        }
    }
}

/// Settles a horizontal scroll on the nearest of the grid's stops, or at the end.
struct FabricGridSnap: ScrollTargetBehavior {
    let columns: Int
    let pages: Int

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let viewport = context.containerSize.width
        guard viewport > 0 else { return }
        let end = max(0, context.contentSize.width - viewport)
        let x = target.rect.minX
        guard x < end - 0.5 else { return }
        let stops = FabricGridMetrics(viewport: viewport, columns: columns).stops(pages: pages) + [end]
        if let nearest = stops.min(by: { abs($0 - x) < abs($1 - x) }) {
            target.rect.origin.x = min(nearest, end)
        }
    }
}
