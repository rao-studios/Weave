//
//  HostTarget.swift
//  WeaveKit
//
//  The host is the Sewn the woven Threads register with as their mothership: the main AII's
//  (~/.rao, the one every Rao app shares) or a Sewn Weave starts in one of the homes it spawned.
//

import Foundation

/// Which AII is the host.
public enum HostSelection: Codable, Sendable, Hashable, CustomStringConvertible {
    /// The main AII: ~/.rao's Sewn (47080/47091).
    case main
    /// A spawned AII, by name: Weave runs `AIIServer sewn` in its home.
    case spawned(String)

    public var description: String {
        switch self {
        case .main: return "main AII"
        case .spawned(let name): return name
        }
    }

    public var spawnedName: String? {
        if case .spawned(let name) = self { return name }
        return nil
    }
}

/// The host, resolved: where its Sewn listens and whose secret Weave presents to it.
public struct HostTarget: Codable, Sendable, Hashable {
    public var selection: HostSelection
    /// The AII home the host Sewn runs in.
    public var homeRoot: String
    public var sewnPorts: AIIPorts
    public var threadPorts: AIIPorts

    public init(selection: HostSelection, homeRoot: String, sewnPorts: AIIPorts, threadPorts: AIIPorts) {
        self.selection = selection
        self.homeRoot = homeRoot
        self.sewnPorts = sewnPorts
        self.threadPorts = threadPorts
    }

    public var home: AIIHome { AIIHome(root: URL(fileURLWithPath: homeRoot, isDirectory: true)) }

    /// Weave's secret in the host's home: what /v1/search and /v1/threads are asked with.
    public func secret() -> String? { try? home.readSecret(for: WeaveIdentity.app) }
}

/// One Thread the Explorer can read: the main AII's or a spawned one's.
public enum ThreadRef: Codable, Sendable, Hashable, CustomStringConvertible {
    case main
    case spawned(String)

    public var description: String {
        switch self {
        case .main: return "main AII"
        case .spawned(let name): return name
        }
    }
}
