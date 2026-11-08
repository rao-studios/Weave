//
//  ConnectService.swift
//  Weave
//
//  The Connect page's working parts: which AII the examples name, which language they are in, and
//  each example run against Weave's own port (its status, its answer, how long it took), so the
//  person sees a request work before copying it. The menu and an AII's card open the page on an AII.
//

import Foundation
import Granite
import WeaveKit

struct ConnectService: GraniteService {
    @Service(.online) var center: Center
    init() {}
}

extension ConnectService: @unchecked Sendable {}

extension ConnectService {
    func set(_ kind: Set.Meta.Kind) {
        let service = self
        onMain { service.center.set.send(Set.Meta(kind: kind)) }
    }

    /// Sends `example` to Weave's port now, as another app would.
    func run(_ example: RequestExample, port: Int, requireSecret: Bool) {
        let service = self
        onMain { service.center.run.send(Run.Meta(example: example, port: port, requireSecret: requireSecret)) }
    }
}
