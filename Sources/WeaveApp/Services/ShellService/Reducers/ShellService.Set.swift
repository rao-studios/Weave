//
//  ShellService.Set.swift
//  Weave
//

import Foundation
import Granite
import WeaveKit

extension ShellService {
    struct Set: GraniteReducer {
        typealias Center = ShellService.Center
        init() {}

        struct Meta: GranitePayload {
            enum Kind: Sendable {
                case mode(AppMode)
                case toggleSidebar
                case spawnSheet(Bool)
                case pendingRemove(String?)
                case select(ThreadRef?)
                case error(AppError?)
            }
            var kind: Kind
        }

        @Payload var meta: Meta?

        func reduce(state: inout Center.State) {
            guard let meta else { return }
            ShellOps.apply(meta.kind, to: &state)
        }

        var thread: DispatchQueue? { nil }
    }
}
