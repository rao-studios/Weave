//
//  FabricRoot.swift
//  WeaveKit
//
//  The folder the fabric lives in (default ~/Library/Application Support/Weave/AIIs, inside Weave's
//  own folder, apart from ~/.rao): one AII home per spawned instance, `fabric.json` (the host Weave
//  last chose), and `models/huggingface`, a link to the main AII's models folder so nothing is
//  downloaded twice. The link is only a link: removing the fabric never touches the models.
//

import Foundation

public struct FabricFile: Codable, Sendable, Equatable {
    public static let fileName = "fabric.json"
    public static let format = "weave-fabric/1"

    public var format: String
    public var host: HostSelection
    public var mainHome: String
    public var deviceKeyFingerprint: String?
    public var createdAt: Date

    public init(host: HostSelection = .main, mainHome: String, deviceKeyFingerprint: String?, createdAt: Date = Date()) {
        self.format = Self.format
        self.host = host
        self.mainHome = mainHome
        self.deviceKeyFingerprint = deviceKeyFingerprint
        self.createdAt = Date(timeIntervalSince1970: createdAt.timeIntervalSince1970.rounded(.down))
    }
}

public enum FabricRoot {
    public static let defaultPath = "~/Library/Application Support/Weave/AIIs"
    /// Where Weave 0.0.0's first builds kept the fabric, inside ~/.rao.
    public static let legacyPath = "~/.rao/weave"

    /// The root's URL, `~` expanded.
    public static func url(_ path: String) -> URL {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(fileURLWithPath: AIIHome.expandTilde(trimmed.isEmpty ? defaultPath : trimmed), isDirectory: true).standardizedFileURL
    }

    public static func sharedModels(root: URL) -> URL {
        root.appendingPathComponent("models", isDirectory: true).appendingPathComponent("huggingface", isDirectory: true)
    }

    /// Whether `directory` (which must exist) supports hard links.
    public static func supportsHardLinks(_ directory: URL) -> Bool {
        let a = directory.appendingPathComponent(".weave-link-\(UUID().uuidString)")
        let b = directory.appendingPathComponent(".weave-link-\(UUID().uuidString)")
        defer { unlink(a.path); unlink(b.path) }
        guard FileManager.default.createFile(atPath: a.path, contents: Data()) else { return false }
        return link(a.path, b.path) == 0
    }

    /// The volume's format, as Finder names it ("APFS", "ExFAT").
    public static func volumeFormat(_ url: URL) -> String? {
        try? url.resourceValues(forKeys: [.volumeLocalizedFormatDescriptionKey]).volumeLocalizedFormatDescription
    }

    /// Throws unless `root` can hold AII homes. With `mustExist` (a custom location, maybe on a
    /// drive that is not connected), a missing folder is refused rather than made.
    public static func usable(_ root: URL, mustExist: Bool = false) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory) else {
            if mustExist { throw FabricError.unavailable(root.path) }
            return
        }
        guard isDirectory.boolValue, supportsHardLinks(root) else { throw FabricError.noHardLinks(root.path, format: volumeFormat(root)) }
    }

    /// Removes what Weave made in `root` and nothing else: every AII home (a folder with a
    /// `weave.json`), `fabric.json` and the models link, then the folder itself only if that left
    /// it empty. A custom location may be a folder that holds other things.
    public static func removeFabric(root: URL) {
        let fm = FileManager.default
        for record in records(root: root) { try? fm.removeItem(atPath: record.home) }
        try? fm.removeItem(at: root.appendingPathComponent(FabricFile.fileName))
        let models = root.appendingPathComponent("models", isDirectory: true)
        try? fm.removeItem(at: sharedModels(root: root))
        if (try? fm.contentsOfDirectory(atPath: models.path))?.isEmpty == true { try? fm.removeItem(at: models) }
        if (try? fm.contentsOfDirectory(atPath: root.path))?.filter({ $0 != ".DS_Store" }).isEmpty == true { try? fm.removeItem(at: root) }
    }

    /// Makes the root exist, checks it can hold AII homes, links the shared models folder and
    /// writes `fabric.json` when absent. Answers the fabric file.
    @discardableResult
    public static func ensure(root: URL, main: AIIHome = .resolved()) throws -> FabricFile {
        try PrivateFile.ensureDirectory(root)
        try usable(root)
        let models = sharedModels(root: root)
        if !FileManager.default.fileExists(atPath: models.path) {
            try FileManager.default.createDirectory(at: models.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: main.huggingFaceHome.path) {
                try FileManager.default.createSymbolicLink(at: models, withDestinationURL: main.huggingFaceHome)
            } else {
                try FileManager.default.createDirectory(at: models, withIntermediateDirectories: true)
            }
        }
        if let file = load(root: root) { return file }
        let fingerprint = (try? AIIDeviceKey.loadOrCreate(home: main))?.key.fingerprint
        let file = FabricFile(mainHome: PrivateFile.path(main.root), deviceKeyFingerprint: fingerprint)
        try save(file, root: root)
        return file
    }

    public static func load(root: URL) -> FabricFile? {
        let url = root.appendingPathComponent(FabricFile.fileName)
        guard let data = FileManager.default.contents(atPath: url.path),
              let file = try? AIIHome.decoder.decode(FabricFile.self, from: data), file.format == FabricFile.format else { return nil }
        return file
    }

    public static func save(_ file: FabricFile, root: URL) throws {
        try PrivateFile.writeAtomically(try AIIHome.encoder.encode(file), to: root.appendingPathComponent(FabricFile.fileName), mode: 0o600)
    }

    /// Removes what Weave's first builds left in ~/.rao: an empty `weave` fabric folder (its
    /// fabric.json and models link only) and an empty `apps/weave`. A legacy folder still holding
    /// AIIs is kept and named, never deleted.
    @discardableResult
    public static func sweepLegacy(main: AIIHome = .resolved()) -> String? {
        let fm = FileManager.default
        let legacy = main.root.appendingPathComponent("weave", isDirectory: true)
        if fm.fileExists(atPath: legacy.path) {
            if records(root: legacy).isEmpty { try? fm.removeItem(at: legacy) }
            else { return "AIIs from an earlier Weave are still in \(legacy.path): choose that folder in Settings to manage them." }
        }
        let apps = main.appDirectory(WeaveIdentity.app)
        if (try? fm.contentsOfDirectory(atPath: apps.path))?.isEmpty == true { try? fm.removeItem(at: apps) }
        return nil
    }

    /// The bytes the fabric holds on disk. The models link is not followed: the models are ~/.rao's.
    public static func diskUsage(root: URL) -> Int64 {
        let keys: Swift.Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys)) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in walker {
            guard let values = try? url.resourceValues(forKeys: keys), values.isSymbolicLink != true, values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    /// Every instance under the root, by name.
    public static func records(root: URL) -> [ThreadRecord] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        return names.sorted().compactMap { name in
            ThreadRecord.load(home: root.appendingPathComponent(name, isDirectory: true))
        }
    }
}
