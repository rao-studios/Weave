//
//  AppError.swift
//  Weave
//

import Foundation
import WeaveKit

struct AppError: Sendable, Equatable, Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(_ title: String, _ error: Error) {
        self.title = title
        self.message = FabricOps.message(error)
    }

    init(_ title: String, message: String) {
        self.title = title
        self.message = message
    }
}
