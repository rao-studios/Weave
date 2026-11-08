//
//  ThreadRecord.swift
//  WeaveKit
//
//  What Weave writes beside each AII it spawns: `<home>/weave.json`, the instance (its name, its
//  slot's four ports, its graph backend, whether it is woven in), and `<home>/aii/run/weave-launch.json`,
//  the shape the running Thread was launched with. AII adopts a running server by its run record
//  and its port, never by its arguments, so the sidecar is the only record of which mothership a
//  running Thread registered with.
//

import Foundation

public struct ThreadRecord: Codable, Sendable, Equatable, Identifiable, Hashable {
    public static let fileName = "weave.json"
    public static let format = "weave-instance/1"

    public var format: String
    public var name: String
    /// The home's absolute path, as found on disk (rewritten at every scan).
    public var home: String
    public var createdAt: Date
    public var threadHTTP: Int
    public var threadGRPC: Int
    public var sewnHTTP: Int
    public var sewnGRPC: Int
    /// `mlx` (on-device extraction) or `keyword`.
    public var graphBackend: String
    /// Registered with the host's Sewn when running.
    public var woven: Bool
    /// The AII home, when `home` cannot hold one. A volume without hard links (an ExFAT drive)
    /// cannot take an AII's secrets and device key, so its home (secrets, keys, config, logs)
    /// stays in Weave's folder on this Mac and `home` holds this file and the data the AII
    /// writes: `thread/` and, as a host, `sewn/`. Nil: `home` is the AII home.
    public var aiiHomePath: String?

    public init(name: String, home: String, createdAt: Date, slot: PortSlot, graphBackend: String, woven: Bool,
                aiiHomePath: String? = nil) {
        self.format = Self.format
        self.name = name
        self.home = home
        self.createdAt = Date(timeIntervalSince1970: createdAt.timeIntervalSince1970.rounded(.down))
        self.threadHTTP = slot.threadHTTP
        self.threadGRPC = slot.threadGRPC
        self.sewnHTTP = slot.sewnHTTP
        self.sewnGRPC = slot.sewnGRPC
        self.graphBackend = graphBackend
        self.woven = woven
        self.aiiHomePath = aiiHomePath
    }

    public var id: String { name }
    public var threadPorts: AIIPorts { AIIPorts(http: threadHTTP, grpc: threadGRPC) }
    public var sewnPorts: AIIPorts { AIIPorts(http: sewnHTTP, grpc: sewnGRPC) }
    public var ports: [Int] { [threadHTTP, threadGRPC, sewnHTTP, sewnGRPC] }
    public var aiiHome: AIIHome { AIIHome(root: URL(fileURLWithPath: aiiHomePath ?? home, isDirectory: true)) }
    /// The fabric folder this record lives in.
    public var fabricRoot: URL { URL(fileURLWithPath: home, isDirectory: true).deletingLastPathComponent() }
    /// Where the AII writes its data when its home is kept apart; nil when the home holds it.
    public var dataDirectories: (thread: URL, sewn: URL)? {
        guard aiiHomePath != nil else { return nil }
        let folder = URL(fileURLWithPath: home, isDirectory: true)
        return (folder.appendingPathComponent("thread", isDirectory: true), folder.appendingPathComponent("sewn", isDirectory: true))
    }

    /// A lowercase handle, the same rule as an AII app name: `^[a-z][a-z0-9]{1,31}$`.
    public static func isValidName(_ name: String) -> Bool { AIIApp.isValidName(name) }

    public static func url(in home: URL) -> URL { home.appendingPathComponent(fileName) }

    public static func load(home: URL) -> ThreadRecord? {
        guard let data = FileManager.default.contents(atPath: url(in: home).path),
              var record = try? AIIHome.decoder.decode(ThreadRecord.self, from: data),
              record.format == format else { return nil }
        record.home = home.standardizedFileURL.path
        return record
    }

    public func write() throws {
        let home = URL(fileURLWithPath: self.home, isDirectory: true)
        try PrivateFile.writeAtomically(try AIIHome.encoder.encode(self), to: Self.url(in: home), mode: 0o600)
    }
}

/// How a running Thread was launched.
public struct LaunchShape: Codable, Sendable, Equatable, Hashable {
    public static let fileName = "weave-launch.json"

    /// The mothership's gRPC port it registered with; nil when it runs standalone.
    public var mothershipGRPCPort: Int?
    public var graphBackend: String
    public var launchedAt: Date

    public init(mothershipGRPCPort: Int?, graphBackend: String, launchedAt: Date) {
        self.mothershipGRPCPort = mothershipGRPCPort
        self.graphBackend = graphBackend
        self.launchedAt = launchedAt
    }

    public static func url(for home: AIIHome) -> URL { home.aiiRunDirectory.appendingPathComponent(fileName) }

    public static func load(home: AIIHome) -> LaunchShape? {
        guard let data = FileManager.default.contents(atPath: url(for: home).path) else { return nil }
        return try? AIIHome.decoder.decode(LaunchShape.self, from: data)
    }

    public func write(home: AIIHome) throws {
        try PrivateFile.ensureDirectory(home.aiiRunDirectory)
        try PrivateFile.writeAtomically(try AIIHome.encoder.encode(self), to: Self.url(for: home), mode: 0o600)
    }

    public static func remove(home: AIIHome) { try? FileManager.default.removeItem(at: url(for: home)) }
}
