//
//  SettingsService.swift
//  Weave
//
//  Weave's preferences, persisted by Granite (`weave.settings.0002`; the self-test writes its own
//  file and never touches the person's). No secret lives here: the AII homes hold those.
//

import Foundation
import Granite
import SwiftUI
import WeaveKit

struct SettingsService: GraniteService {
    @Service(.online) var center: Center
    init() {}

    /// Bump the suffix when a stored value's meaning changes: the old file is simply not read.
    /// 0002: the fabric lives in Weave's own folder, not ~/.rao/weave (2026-11-08).
    static var persistenceKey: String {
        CommandLine.arguments.contains("--self-test") ? "weave.settings.self-test.0002" : "weave.settings.0002"
    }
}

extension SettingsService: @unchecked Sendable {}

extension SettingsService {
    func set(_ kind: Set.Meta.Kind) {
        let service = self
        onMain { service.center.set.send(Set.Meta(kind: kind)) }
    }

    func update<V: Sendable>(_ keyPath: WritableKeyPath<Center.State, V>, _ value: V) {
        nonisolated(unsafe) let keyPath = keyPath
        set(.write { $0[keyPath: keyPath] = value })
    }

    /// A control bound to one field; commits synchronously on main (`thread: nil`).
    func binding<V: Sendable>(_ keyPath: WritableKeyPath<Center.State, V>) -> Binding<V> {
        Binding(get: { self.state[keyPath: keyPath] }, set: { self.update(keyPath, $0) })
    }
}
