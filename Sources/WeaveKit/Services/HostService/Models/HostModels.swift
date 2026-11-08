//
//  HostModels.swift
//  WeaveKit
//

import Foundation

/// The host Sewn, as Weave last found it.
public enum ServerStatus: Sendable, Equatable, Hashable {
    case unknown
    case starting
    case up
    case down(String)

    public var isUp: Bool { self == .up }
    public var label: String {
        switch self {
        case .unknown: return "unknown"
        case .starting: return "starting"
        case .up: return "up"
        case .down: return "down"
        }
    }
}

extension HostService {
    public enum Reply: Sendable {
        case target(HostTarget)
        case done
    }
}
