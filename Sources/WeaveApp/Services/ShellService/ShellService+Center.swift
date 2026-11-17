//
//  ShellService+Center.swift
//  Weave
//

import Foundation
import Granite
import WeaveKit

extension ShellService {
    struct Center: GraniteCenter {
        struct State: TransientState {
            var mode: AppMode = .fabric
            var sidebarVisible = true
            var spawnSheet = false
            var pendingRemove: String?
            /// The instance whose AII the Label sheet names, while it shows.
            var labelSheet: String?
            var pendingStorage: StorageAction?
            var selectedThread: ThreadRef?
            var error: AppError?
            init() {}
        }

        @Event var set: Set.Reducer
        @Store var state: State
        init() {}
    }
}
