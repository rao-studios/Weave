//
//  FabricList.swift
//  Weave
//
//  The Fabric's AIIs as a list, one full-width row each. A row never goes narrower than its details
//  and counts read at: in a narrower window the list scrolls sideways instead.
//

import SwiftUI
import WeaveKit

enum FabricListMetrics {
    /// The mark, the details beside the counts, and the row's padding.
    static let minRowWidth: CGFloat = 740
    static let spacing: CGFloat = 10
}

struct FabricList<Row: View>: View {
    let records: [ThreadRecord]
    @ViewBuilder let row: (ThreadRecord) -> Row

    var body: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: FabricListMetrics.spacing) {
                ForEach(records) { record in row(record) }
            }
            .containerRelativeFrame(.horizontal, alignment: .topLeading) { length, _ in
                max(length, FabricListMetrics.minRowWidth)
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }
}
