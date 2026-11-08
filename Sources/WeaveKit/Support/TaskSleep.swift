//
//  TaskSleep.swift
//  WeaveKit
//
//  The one way Weave sleeps inside a long-lived task: a number of seconds, through the nanoseconds
//  overload, in a frame of its own. The update loop sleeps through it.
//
//  NEVER `Task.sleep(for:)` in such a loop. Its specialized `Task.sleep(for:tolerance:clock:)`,
//  inlined into a task's closure in Craft's release build, aborted the process in
//  `swift_task_dealloc` on the update loop's first wake in Craft's first 0.0.0 release, 90 seconds
//  after every launch (2026-10-26). The `nanoseconds` overload stays off the clock-based path, and
//  `@inline(never)` keeps the sleep's frame here, out of the caller's closure. TaskSleepTests fails
//  on a clock-based sleep under Sources/.
//

import Foundation

public enum TaskSleep {
    /// Sleeps `seconds` (negative counts as none).
    @inline(never)
    public static func seconds(_ seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64((max(0, seconds) * 1_000_000_000).rounded()))
    }
}

extension Duration {
    /// The duration in seconds, for `TaskSleep.seconds`.
    public var seconds: Double { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
}
