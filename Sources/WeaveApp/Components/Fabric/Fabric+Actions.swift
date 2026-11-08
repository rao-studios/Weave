//
//  Fabric+Actions.swift
//  Weave
//
//  What a row's buttons do, through the root (they cross the fabric and the host).
//

import SwiftUI
import WeaveKit

extension Fabric {
    func perform(_ action: ThreadRowAction) {
        let root = WeaveAppRoot.shared
        switch action.kind {
        case .start: root.start(action.name)
        case .stop: root.stop(action.name)
        case .restart: root.restart(action.name)
        case .explore: root.explore(.spawned(action.name))
        case .remove: root.confirmRemove(action.name)
        case .reveal: root.revealHome(action.name)
        case .weaveIn: root.setWoven(action.name, true)
        case .weaveOut: root.setWoven(action.name, false)
        case .host: root.selectHost(.spawned(action.name))
        case .connect: root.showConnect(action.name)
        }
    }
}
