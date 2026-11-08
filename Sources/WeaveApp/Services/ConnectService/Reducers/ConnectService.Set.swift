//
//  ConnectService.Set.swift
//  Weave
//

import Foundation
import Granite
import WeaveKit

extension ConnectService {
    struct Set: GraniteReducer {
        typealias Center = ConnectService.Center
        init() {}

        struct Meta: GranitePayload {
            enum Kind: Sendable {
                case thread(String?)
                case format(RequestFormat)
                case result(String, ConnectOps.Result)
            }
            var kind: Kind
        }

        @Payload var meta: Meta?

        func reduce(state: inout Center.State) {
            guard let meta else { return }
            ConnectOps.apply(meta.kind, to: &state)
        }

        var thread: DispatchQueue? { nil }
    }
}
