//
//  Live.swift
//  WeaveKit
//
//  The live instance of a service, resolved when it is needed instead of stored. A reducer that
//  holds a stored `@Relay` to its own service recurses while the relay is being built (the relay
//  is inserted into Granite's shared repository only after its reducers are set up, and setting
//  up a reducer builds its relays): it crashes with signal 11. The same holds for two services
//  whose reducers relay to each other. So a reducer stores relays only to services *below* it,
//  and reaches its own service (to write through `set`) with `Live.service` from its effect,
//  which runs on main after construction.
//

import Foundation
import Granite

public enum Live {
    nonisolated(unsafe) private static var cache: [ObjectIdentifier: Any] = [:]
    private static let lock = NSLock()

    /// Call on the main thread (a `thread: .main` reducer's `effect`, a view, a root).
    public static func service<S: GraniteService>(_ type: S.Type = S.self) -> S {
        let key = ObjectIdentifier(type)
        lock.lock()
        if let cached = cache[key] as? S { lock.unlock(); return cached }
        lock.unlock()
        let resolved = MainActor.assumeIsolated { Relay<S>().wrappedValue }
        lock.lock(); cache[key] = resolved; lock.unlock()
        return resolved
    }
}
