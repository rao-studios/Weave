//
//  WeavePortPlan.swift
//  WeaveKit
//
//  Weave's ports. Its own HTTP port is 47600; spawned AII n (1…39) owns the slot
//  47600 + 10n + {1 Thread HTTP, 2 Thread gRPC, 3 Sewn HTTP, 4 Sewn gRPC}: clear of the main
//  stack's 47080/47081/47090/47091, Braid's demo pairs (47181…47590) and AII's reserved ports.
//  A slot is taken when any of its ports answers a connect or another record already holds it.
//

import Foundation
#if canImport(Darwin)
import Darwin
#endif

public struct PortSlot: Sendable, Equatable, Hashable {
    public let index: Int
    public var threadHTTP: Int { WeavePortPlan.base + 10 * index + 1 }
    public var threadGRPC: Int { WeavePortPlan.base + 10 * index + 2 }
    public var sewnHTTP: Int { WeavePortPlan.base + 10 * index + 3 }
    public var sewnGRPC: Int { WeavePortPlan.base + 10 * index + 4 }
    public var ports: [Int] { [threadHTTP, threadGRPC, sewnHTTP, sewnGRPC] }
    public var threadPorts: AIIPorts { AIIPorts(http: threadHTTP, grpc: threadGRPC) }
    public var sewnPorts: AIIPorts { AIIPorts(http: sewnHTTP, grpc: sewnGRPC) }
}

public enum WeavePortPlan {
    public static let base = 47600
    public static let slots = 1...39

    public static func slot(_ index: Int) -> PortSlot { PortSlot(index: index) }

    /// The first slot none of whose ports is `taken` (by a record) or answers on 127.0.0.1.
    public static func freeSlot(taken: Set<Int>, listening: (Int) -> Bool = isListening) -> PortSlot? {
        for index in slots {
            let slot = PortSlot(index: index)
            if slot.ports.contains(where: { taken.contains($0) || AIIPortPlan.reservedElsewhere.contains($0) }) { continue }
            if slot.ports.contains(where: listening) { continue }
            return slot
        }
        return nil
    }

    /// Whether something accepts a TCP connection on 127.0.0.1:`port` (Braid's probe).
    public static func isListening(port: Int) -> Bool {
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else { return false }
        defer { close(socket) }
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        return result == 0
    }
}
