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
        case .select(let ref):
            state.selectedThread = ref
            if ref != nil { state.mode = .explorer }
        case .error(let error): state.error = error
        }
    }

    /// `--mode=<page>` at launch.
    static func launchKinds(_ arguments: [String]) -> [ShellService.Set.Meta.Kind] {
        arguments.compactMap { argument in
            guard argument.hasPrefix("--mode="), let mode = AppMode(rawValue: String(argument.dropFirst(7))) else { return nil }
            return .mode(mode)
        }
    }
}
