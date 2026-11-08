//
//  ShellService.swift
//  Weave
//
//  The window's shell as a service: the page, the sidebar, the spawn sheet, the instance waiting
//  for a remove confirmation, the Thread the Explorer shows, and the error being presented. The
//  menus and the root set these as much as the views do, and AppKit cannot reach a component's
//  center.
//

import Foundation
import Granite
import WeaveKit

struct ShellService: GraniteService {
    @Service(.online) var center: Center
    init() {}
}

extension ShellService: @unchecked Sendable {}

extension ShellService {
    func set(_ kind: Set.Meta.Kind) {
        let service = self
        onMain { service.center.set.send(Set.Meta(kind: kind)) }
    }

    func present(_ error: AppError) { set(.error(error)) }

    func show(_ mode: AppMode) { set(.mode(mode)) }
}
