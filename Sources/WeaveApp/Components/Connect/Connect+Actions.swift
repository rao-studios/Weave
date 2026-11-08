//
//  Connect+Actions.swift
//  Weave
//

import AppKit
import SwiftUI

extension Connect {
    /// Puts `code` on the clipboard and says so on its button for a moment.
    func copy(_ code: String, id: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        _state.copied.wrappedValue = id
        let copied = _state.copied
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if copied.wrappedValue == id { copied.wrappedValue = nil }
        }
    }
}
