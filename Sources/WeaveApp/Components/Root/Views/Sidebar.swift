//
//  Sidebar.swift
//  Weave
//
//  The pages, then the fabric at a glance: the main AII and every spawned one, each with its dot,
//  the host's ringed in the accent. A row opens that Thread in the Explorer.
//

import Granite
import SwiftUI
import WeaveKit

struct Sidebar: View {
    @Relay var shell: ShellService
    @Relay var fabric: FabricService
    @Relay var host: HostService
    @StateObject var clock = RelayClock([RelayClock.on(ShellService.self), RelayClock.on(FabricService.self),
                                         RelayClock.on(HostService.self)])

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                WeaveMark(size: 22)
                Text("Weave").font(.weaveSerif(19, weight: .medium, italic: true)).foregroundStyle(Color.weaveInk)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 16)

            VStack(spacing: 2) {
                ForEach(AppMode.allCases, id: \.self) { mode in
                    pageRow(mode)
                }
            }
            .padding(.horizontal, 8)

            SectionCaption("AIIs").padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 6)
            ScrollView {
                VStack(spacing: 2) {
                    threadRow(.main, title: "main AII", subtitle: "~/.rao", status: mainStatus, isHost: host.state.selection == .main)
                    ForEach(fabric.state.threads) { record in
                        threadRow(.spawned(record.name), title: record.name, subtitle: "\(record.threadHTTP)",
                                  status: StatusDot.State(fabric.state.status(of: record.name)),
                                  isHost: host.state.selection == .spawned(record.name), woven: record.woven)
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 0)
            Button { WeaveAppRoot.shared.showSpawn() } label: {
                Label("Spawn AII", systemImage: "plus").frame(maxWidth: .infinity)
            }
            .buttonStyle(WeaveButtonStyle(prominent: true))
            .padding(12)
        }
        .background(Color.weaveInk.opacity(0.025))
    }

    private var mainStatus: StatusDot.State {
        host.state.selection == .main ? StatusDot.State(host.state.sewn) : .unknown
    }

    private func pageRow(_ mode: AppMode) -> some View {
        let active = shell.state.mode == mode
        return Button { WeaveAppRoot.shared.show(mode) } label: {
            HStack(spacing: 10) {
                Image(systemName: mode.symbol).frame(width: 18)
                Text(mode.title).font(.weaveSans(12.5, weight: active ? .semibold : .regular))
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 6).fill(active ? Color.weaveInk.opacity(0.08) : .clear))
            .foregroundStyle(Color.weaveInk.opacity(active ? 1 : 0.7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func threadRow(_ ref: ThreadRef, title: String, subtitle: String, status: StatusDot.State, isHost: Bool,
                           woven: Bool = true) -> some View {
        let selected = shell.state.mode == .explorer && shell.state.selectedThread == ref
        return Button { WeaveAppRoot.shared.explore(ref) } label: {
            HStack(spacing: 8) {
                StatusDot(state: status, size: 7)
                Text(title).font(.weaveSans(12, weight: selected ? .semibold : .regular)).lineLimit(1)
                if isHost { Pill(text: "host", tint: .weaveAccent) }
                else if !woven { Pill(text: "loose") }
                Spacer()
                Text(subtitle).font(.weaveMono(9.5)).foregroundStyle(Color.weaveInk.opacity(0.4))
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 6).fill(selected ? Color.weaveInk.opacity(0.08) : .clear))
            .foregroundStyle(Color.weaveInk)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
