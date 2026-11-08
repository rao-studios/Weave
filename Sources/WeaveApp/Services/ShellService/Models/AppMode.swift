//
//  AppMode.swift
//  Weave
//

import Foundation

enum AppMode: String, CaseIterable, Sendable, Hashable {
    case fabric, explorer, search, settings

    var title: String {
        switch self {
        case .fabric: return "Fabric"
        case .explorer: return "Explorer"
        case .search: return "Search"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .fabric: return "square.grid.3x3"
        case .explorer: return "doc.text.magnifyingglass"
        case .search: return "point.3.connected.trianglepath.dotted"
        case .settings: return "gearshape"
        }
    }
}
