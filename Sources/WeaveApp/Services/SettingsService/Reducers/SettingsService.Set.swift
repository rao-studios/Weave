//
//  SettingsService.Set.swift
//  Weave
//
//  The one writer. `thread: nil`: every send arrives on main, so a bound control reads back what
//  it wrote in the same turn.
//

import Foundation
import Granite

extension SettingsService {
    struct Set: GraniteReducer {
        typealias Center = SettingsService.Center
        init() {}

        struct Meta: GranitePayload {
            enum Kind: Sendable {
                case write(@Sendable (inout Center.State) -> Void)
                case reset
            }
            var kind: Kind
        }

        @Payload var meta: Meta?

        func reduce(state: inout Center.State) {
            guard let meta else { return }
            SettingsOps.apply(meta.kind, to: &state)
        }

        var thread: DispatchQueue? { nil }
    }
}
