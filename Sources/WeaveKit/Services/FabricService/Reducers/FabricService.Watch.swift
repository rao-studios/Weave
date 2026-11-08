//
//  FabricService.Watch.swift
//  WeaveKit
//
//  The probe loop: every `interval` seconds, each idle Thread's /health and counts. Its Task is a
//  resident; a nil interval cancels it.
//

import Foundation
import Granite

extension FabricService {
    public struct Watch: GraniteReducer {
        public typealias Center = FabricService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public let interval: Double?
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta else { return }
            state.loopRunning = meta.interval != nil
            if let interval = meta.interval { state.interval = max(1, interval) }
        }

        public func effect(state: Center.State) -> GraniteEffect {
            guard let meta else { return .none }
            FabricService.tasks.remove("fabric/loop")?.cancel()
            guard meta.interval != nil else { return .none }
            let fabric = Live.service(FabricService.self)
            let task = Task {
                while !Task.isCancelled {
                    await FabricOps.tick(fabric)
                    let interval = await MainActor.run { fabric.state.interval }
                    try? await TaskSleep.seconds(interval)
                }
            }
            FabricService.tasks.put("fabric/loop", task)
            return .none
        }

        public var thread: DispatchQueue? { .main }
    }
}
