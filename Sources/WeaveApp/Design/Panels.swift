//
//  Panels.swift
//  Weave
//
//  Layout pieces several pages share: a card, a page header, a key/value row, an empty state, and
//  the PaneStack that keeps every page alive (Veil's) so switching never drops what a page loaded.
//

import SwiftUI

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.weaveCard))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.weaveBorder, lineWidth: 1))
    }
}

struct PageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.weaveSerif(26, weight: .medium, italic: true)).foregroundStyle(Color.weaveInk)
                Text(subtitle).font(.weaveSans(12)).foregroundStyle(Color.weaveInk.opacity(0.55))
            }
            Spacer()
            trailing
        }
    }
}

struct KeyValueRow: View {
    let key: String
    let value: String
    var mono = true
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(key).font(.weaveSans(11)).foregroundStyle(Color.weaveInk.opacity(0.5)).frame(width: 120, alignment: .leading)
            Text(value).font(mono ? .weaveMono(11) : .weaveSans(12)).foregroundStyle(Color.weaveInk).textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}

struct EmptyState: View {
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 8) {
            WeaveMark(size: 34).opacity(0.7)
            Text(title).font(.weaveSerif(17, italic: true)).foregroundStyle(Color.weaveInk.opacity(0.75))
            Text(message).font(.weaveSans(12)).foregroundStyle(Color.weaveInk.opacity(0.5)).multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}

/// An error line under a control.
struct ErrorLine: View {
    let message: String?
    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.weaveSans(11))
                .foregroundStyle(Color.weaveError)
                .textSelection(.enabled)
        }
    }
}

/// Lays every page out at full size and keeps it alive; only `active` is shown.
struct PaneStack: Layout {
    let active: Int

    struct Cache { var sizes: [CGSize?] }

    func makeCache(subviews: Subviews) -> Cache { Cache(sizes: Array(repeating: nil, count: subviews.count)) }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        if cache.sizes.count != subviews.count { cache = makeCache(subviews: subviews) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        for (index, subview) in subviews.enumerated() {
            let size = index == active ? bounds.size : cache.sizes[index] ?? bounds.size
            cache.sizes[index] = size
            subview.place(at: bounds.origin, proposal: ProposedViewSize(size))
        }
    }
}

extension View {
    func paneVisible(_ visible: Bool) -> some View {
        opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
    }
}
