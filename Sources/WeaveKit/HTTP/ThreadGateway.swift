//
//  ThreadGateway.swift
//  WeaveKit
//
//  How Weave's routing spec names an AII: a spawned AII by its name, the main AII as `main`.
//

import Foundation

public enum ThreadGateway {
    /// The id that reaches the main AII's Thread.
    public static let mainName = "main"

    public static func ref(_ id: String) -> ThreadRef { id == mainName ? .main : .spawned(id) }
}
