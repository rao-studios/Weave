//
//  ShellOps.swift
//  Weave
//

import Foundation
import WeaveKit

enum ShellOps {
    typealias State = ShellService.Center.State

    static func apply(_ kind: ShellService.Set.Meta.Kind, to state: inout State) {
        switch kind {
        case .mode(let mode): state.mode = mode
        case .toggleSidebar: state.sidebarVisible.toggle()
        case .spawnSheet(let on): state.spawnSheet = on
        case .pendingRemove(let name): state.pendingRemove = name
        case .pendingStorage(let action): state.pendingStorage = action
        case .select(let ref):
            state.selectedThread = ref
            if ref != nil { state.mode = .explorer }
        case .error(let error): state.error = error
        }
    }

    /// The value of `<prefix>value` among the launch arguments.
    static func argument(_ prefix: String, in arguments: [String]) -> String? {
        arguments.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// `--mode=<page>` at launch.
    static func launchKinds(_ arguments: [String]) -> [ShellService.Set.Meta.Kind] {
        arguments.compactMap { argument in
            guard argument.hasPrefix("--mode="), let mode = AppMode(rawValue: String(argument.dropFirst(7))) else { return nil }
            return .mode(mode)
        }
    }
}
