//
//  HostService.Watch.swift
//  WeaveKit
//
//  The poll loop: every `interval` seconds, the host's health and the nodes it fans out to.
//

import Foundation
import Granite

extension HostService {
    public struct Watch: GraniteReducer {
        public typealias Center = HostService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public let interval: Double?
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta else { return }
            state.polling = meta.interval != nil
            if let interval = meta.interval { state.pollInterval = max(1, interval) }
        }

        public func effect(state: Center.State) -> GraniteEffect {
            guard let meta else { return .none }
            HostService.tasks.remove("host/poll")?.cancel()
            guard meta.interval != nil else { return .none }
            let host = Live.service(HostService.self)
            let task = Task {
                while !Task.isCancelled {
                    await HostOps.poll(host)
                    let interval = await MainActor.run { host.state.pollInterval }
                    try? await TaskSleep.seconds(interval)
                }
            }
            HostService.tasks.put("host/poll", task)
            return .none
        }

        public var thread: DispatchQueue? { .main }
    }
}
