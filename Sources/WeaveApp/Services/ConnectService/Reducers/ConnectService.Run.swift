//
//  ConnectService.Run.swift
//  Weave
//
//  One example sent to Weave's port: marked running, then its answer written through `set`.
//

import Foundation
import Granite
import WeaveKit

extension ConnectService {
    struct Run: GraniteReducer {
        typealias Center = ConnectService.Center
        init() {}

        struct Meta: GranitePayload {
            let example: RequestExample
            let port: Int
            let requireSecret: Bool
        }

        @Payload var meta: Meta?

        func reduce(state: inout Center.State) {
            guard let meta else { return }
            state.running.insert(meta.example.id)
        }

        func effect(state: Center.State) -> GraniteEffect {
            guard let meta else { return .none }
            let connect = Live.service(ConnectService.self)
            return .run {
                let result = await ConnectOps.send(meta.example, port: meta.port, requireSecret: meta.requireSecret)
                connect.set(.result(meta.example.id, result))
            }
        }

        var thread: DispatchQueue? { .main }
    }
}
