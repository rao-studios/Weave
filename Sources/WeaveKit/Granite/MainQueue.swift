//
//  MainQueue.swift
//  WeaveKit
//
//  A service's `set` from a background effect hops to main (`onMain`) and its `Set` commits there
//  at once (`thread: nil`). Awaiting `flush()` after the last `set` lets every hop enqueued before
//  it run, so the caller a ticket wakes reads the state with the effect's writes in: a spawn's
//  record is there for the start that follows it.
//

import Foundation

public enum MainQueue {
    public static func flush() async {
        await MainActor.run {}
    }
}
