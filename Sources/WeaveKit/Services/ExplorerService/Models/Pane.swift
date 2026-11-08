//
//  Pane.swift
//  WeaveKit
//

import Foundation

/// The Explorer's panes over one Thread.
public enum Pane: String, CaseIterable, Sendable, Hashable, Codable, Identifiable {
    case stats, library, graph, search, deposit, log

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .stats: return "Stats"
        case .library: return "Library"
        case .graph: return "Graph"
        case .search: return "Search"
        case .deposit: return "Deposit"
        case .log: return "Log"
        }
    }
}

extension ExplorerService {
    /// What the Explorer asks of a Thread.
    public enum Request: Sendable, Equatable {
        case stats
        case library
        case graph(entity: String?, query: String?, hops: Int)
        case search(query: String, topK: Int)
        case deposit(text: String, name: String?)
        case log

        public var pane: Pane {
            switch self {
            case .stats: return .stats
            case .library: return .library
            case .graph: return .graph
            case .search: return .search
            case .deposit: return .deposit
            case .log: return .log
            }
        }
    }
}
