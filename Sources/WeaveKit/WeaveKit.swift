//
//  WeaveKit.swift
//  WeaveKit
//
//  WHAT: Everything Weave does but draw: the fabric (the AII homes Weave spawns under a folder the
//        person picks, one `AIIServer thread` each), the host (the Sewn their Threads register with,
//        whose /v1/search fans out across them), Weave's own loopback port, and the Explorer's reads
//        of one Thread. Each subsystem is a Granite service under Services/.
//  OUT:  The services, their value types, and AII re-exported so a client needs one import.
//

@_exported import AII

/// Who Weave is to the Ambient Intelligence Index.
public enum WeaveIdentity {
    /// The app name: its lane, its secret (`secrets/weave`), its folder under `apps/`.
    public static let app: AIIApp = "weave"
    public static let displayName = "Weave"
    public static let bundleIdentifier = "nyc.rao.weave"
    /// The no-account owner Weave's lane files under and Sewn answers it as. Deposits that should be
    /// found by a federated search are filed as this owner.
    public static let owner = "local-weave"
    /// Weave's own HTTP port.
    public static let defaultPort = 47600
}
