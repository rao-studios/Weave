//
//  ErrorSheet.swift
//  Weave
//
//  What went wrong, in a sheet that stays on screen: the message scrolls inside a bounded height
//  (a Thread's start-up log runs long) and can be selected and copied; OK, Return or Escape dismiss it.
//

import AppKit
import SwiftUI

struct ErrorSheet: View {
    let error: AppError
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.weaveError)
                Text(error.title).font(.weaveSerif(22, weight: .medium, italic: true)).foregroundStyle(Color.weaveInk)
            }
            ScrollView {
                Text(error.message)
                    .font(.weaveMono(11))
                    .foregroundStyle(Color.weaveInk)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: 360)
            .fixedSize(horizontal: false, vertical: true)
            .background(Color.weaveInk.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            HStack {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(error.title + "\n\n" + error.message, forType: .string)
                }
                .buttonStyle(WeaveButtonStyle())
                Spacer()
                Button("OK", action: dismiss)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(WeaveButtonStyle(prominent: true))
            }
        }
        .padding(24)
        .frame(width: 560)
        .background(Color.weaveBG)
        .onExitCommand(perform: dismiss)
    }
}
