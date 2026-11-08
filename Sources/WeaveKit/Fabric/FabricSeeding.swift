//
//  FabricSeeding.swift
//  WeaveKit
//
//  WHAT: The one identity scheme behind everything Weave spawns, so a spawned Thread can register
//        with whichever Sewn is the host and every lane stamp resolves on it.
//  HOW:  Weave registers in the main home (~/.rao/secrets/weave: the FABRIC secret). A spawned
//        home is seeded before AII provisions it: its stack secret (`secrets/aii`, what its Thread
//        registers with) is the FABRIC secret, and its device key is a byte copy of the main
//        home's, so every lane id it derives equals the main home's. Then AII's own `provision`
//        keeps the stack secret, mints the home's own app secrets, and writes the lanes.
//  WHY:  Host = main AII: the main keyring resolves the FABRIC secret to app `weave`, so the
//        Threads register as Weave's nodes, which no Rao app's scope admits. Host = a spawned AII:
//        its keyring holds the FABRIC secret as its own stack secret, so every peer registers as
//        `aii`, which Weave's scope admits. Either way the stamped lane is Weave's, the same id in
//        every home.
//  PIN:  AII publishes secrets with link(): the fabric's folder must support hard links (APFS).
//        `AIIDeviceKey`'s hex is internal: the key is copied as the file's bytes.
//

import CryptoKit
import Foundation

public enum FabricError: Error, Equatable, LocalizedError {
    case noWeaveSecret
    case noDeviceKey
    case laneMismatch(String)
    case noHardLinks(String)
    case invalidName(String)
    case exists(String)
    case noFreeSlot
    case softCap(Int)
    case noServer(String)
    case notFound(String)
    case busy(String)
    case noHost

    public var errorDescription: String? {
        switch self {
        case .noWeaveSecret: return "The main AII has no secret for Weave."
        case .noDeviceKey: return "The main AII has no device key to share."
        case .laneMismatch(let name): return "\(name)'s lane for Weave does not match the main AII's."
        case .noHardLinks(let path): return "\(path) cannot hard-link; AII homes need an APFS volume."
        case .invalidName(let name): return "“\(name)” is not a valid name: lowercase letters and digits, starting with a letter, 2–32 long."
        case .exists(let name): return "An AII named \(name) already exists."
        case .noFreeSlot: return "Every port slot Weave plans is in use."
        case .softCap(let n): return "Weave runs at most \(n) AIIs (Settings › Soft cap)."
        case .noServer(let path): return "No AIIServer at \(path). Install the AII (aii install) first."
        case .notFound(let name): return "No AII named \(name)."
        case .busy(let name): return "\(name) is busy."
        case .noHost: return "No host is up."
        }
    }
}

public enum FabricSeeding {
    /// Registers Weave in the main home and answers its secret (the FABRIC secret). Idempotent.
    @discardableResult
    public static func prepareMain(_ main: AIIHome = .resolved()) throws -> String {
        _ = try AIIDeviceKey.loadOrCreate(home: main)
        try main.provision(by: WeaveIdentity.app, displayName: WeaveIdentity.displayName,
                           bundleIdentifier: WeaveIdentity.bundleIdentifier)
        _ = try AIILanes.ensure(home: main, app: WeaveIdentity.app)
        guard let secret = try main.readSecret(for: WeaveIdentity.app) else { throw FabricError.noWeaveSecret }
        return secret
    }

    /// The first eight hex of the secret's SHA-256: shown, never the secret.
    public static func fingerprint(_ secret: String) -> String {
        SHA256.hash(data: Data(secret.utf8)).prefix(4).map { String(format: "%02x", $0) }.joined()
    }

    /// Seeds and provisions a spawned home (see the header).
    public static func provision(home: AIIHome, main: AIIHome, fabric: String) throws {
        try PrivateFile.ensureDirectory(home.root)
        try PrivateFile.ensureDirectory(home.secretsDirectory)
        try PrivateFile.ensureDirectory(home.keysDirectory)
        _ = try PrivateFile.publishIfAbsent(Data(fabric.utf8), to: home.secretFile(for: .stack), mode: 0o600)
        _ = try AIIDeviceKey.loadOrCreate(home: main)
        guard let key = FileManager.default.contents(atPath: PrivateFile.path(main.deviceKeyFile)) else { throw FabricError.noDeviceKey }
        _ = try PrivateFile.publishIfAbsent(key, to: home.deviceKeyFile, mode: 0o600)
        try home.provision(by: WeaveIdentity.app, displayName: WeaveIdentity.displayName,
                           bundleIdentifier: WeaveIdentity.bundleIdentifier)
        _ = try AIILanes.ensure(home: home, app: WeaveIdentity.app)
        guard let mine = home.lane(WeaveIdentity.app)?.id, mine == main.lane(WeaveIdentity.app)?.id else {
            throw FabricError.laneMismatch(home.root.lastPathComponent)
        }
    }

    /// Whether the home's stack secret is still the FABRIC secret.
    public static func verify(home: AIIHome, fabric: String) -> Bool {
        (try? home.readSecret(for: .stack)) == fabric
    }

    /// Rewrites a home's stack secret with the FABRIC secret (its Thread must be stopped).
    public static func reseed(home: AIIHome, fabric: String) throws {
        try PrivateFile.writeAtomically(Data(fabric.utf8), to: home.secretFile(for: .stack), mode: 0o600)
    }

    /// `<home>/models/huggingface` → `<root>/models/huggingface`, so a spawned Thread finds the
    /// embedder and the extractor where every Rao app keeps them.
    public static func shareModels(home: AIIHome, root: URL) throws {
        try PrivateFile.ensureDirectory(home.modelsDirectory)
        let link = home.huggingFaceHome
        let target = FabricRoot.sharedModels(root: root)
        if (try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)) == target.path { return }
        if FileManager.default.fileExists(atPath: link.path) {
            // An empty folder from an earlier run is replaced; anything else is the person's and stays.
            let contents = (try? FileManager.default.contentsOfDirectory(atPath: link.path)) ?? []
            guard contents.isEmpty else { return }
            try FileManager.default.removeItem(at: link)
        }
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
    }
}
