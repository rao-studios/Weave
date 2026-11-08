//
//  MainHop.swift
//  WeaveKit
//
//  Granite's `send` stores its payload on the calling thread while the main queue commits the
//  previous send into the same slot; from another thread the two race (a double release, Signal 11,
//  in Ambient on 2026-10-05). Every service's helpers send through this: inline on main, hopped
//  from anywhere else, so each writer's order is kept by the main queue.
//

import Foundation

@inlinable
public func onMain(_ body: @escaping @Sendable () -> Void) {
    if Thread.isMainThread {
        body()
    } else {
        DispatchQueue.main.async(execute: body)
    }
}
