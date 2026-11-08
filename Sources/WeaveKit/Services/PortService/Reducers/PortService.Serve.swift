//
//  PortService.Serve.swift
//  WeaveKit
//
//  Starts Weave's server on a port (replacing one already running), or stops it (port nil).
//

import Foundation
import Granite

extension PortService {
    public struct Serve: GraniteReducer {
        public typealias Center = PortService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public let port: Int?
            public let requireSecret: Bool
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta else { return }
            state.generation += 1
            state.enabled = meta.port != nil
            state.listening = false
            state.requireSecret = meta.requireSecret
            state.lastError = nil
            if let port = meta.port { state.port = port }
        }

        public func effect(state: Center.State) -> GraniteEffect {
            guard let meta else { return .none }
            PortService.tasks.remove("port/server")?.cancel()
            guard let port = meta.port else { return .none }
            let service = Live.service(PortService.self)
            let generation = state.generation
            let source = LiveGatewaySource(port: port)
            let application = WeaveServer.application(port: port, source: source, requireSecret: meta.requireSecret) {
                service.set(.listening(true, generation: generation))
            }
            let task = Task {
                do {
                    try await application.runService(gracefulShutdownSignals: [])
                    service.set(.listening(false, generation: generation))
                } catch {
                    service.set(.failed("port \(port): \(FabricOps.message(error))", generation: generation))
                }
            }
            PortService.tasks.put("port/server", task)
            return .none
        }

        public var thread: DispatchQueue? { .main }
    }
}
