//
//  AppMode.swift
//  Weave
//

import Foundation

/// A storage action waiting for its confirmation.
enum StorageAction: Sendable, Equatable {
    case removeAll
    case uninstall
}

enum AppMode: String, CaseIterable, Sendable, Hashable {
    case fabric, explorer, search, connect, settings

    var title: String {
        switch self {
        case .fabric: return "Fabric"
        case .explorer: return "Explorer"
        case .search: return "Search"
        case .connect: return "Connect"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .fabric: return "square.grid.3x3"
        case .explorer: return "doc.text.magnifyingglass"
        case .search: return "point.3.connected.trianglepath.dotted"
        case .connect: return "chevron.left.forwardslash.chevron.right"
        case .settings: return "gearshape"
        }
    }
}
