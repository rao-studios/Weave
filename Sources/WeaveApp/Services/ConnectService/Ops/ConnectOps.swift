//
//  ConnectOps.swift
//  Weave
//

import Foundation
import WeaveKit

enum ConnectOps {
    typealias State = ConnectService.Center.State

    struct Result: Sendable, Equatable {
        var status: Int
        var body: String
        var milliseconds: Double
        var ok: Bool { (200..<300).contains(status) }
    }

    static func apply(_ kind: ConnectService.Set.Meta.Kind, to state: inout State) {
        switch kind {
        case .thread(let thread):
            if thread != state.thread { state.results = [:] }
            state.thread = thread
        case .format(let format):
            state.format = format
        case .result(let id, let result):
            state.results[id] = result
            state.running.remove(id)
        }
    }

    /// The AII the examples name: the chosen one when it still exists, else the first spawned one, else `main`.
    static func thread(_ chosen: String?, records: [ThreadRecord]) -> String {
        if let chosen, chosen == ThreadGateway.mainName || records.contains(where: { $0.name == chosen }) { return chosen }
        return records.first?.name ?? ThreadGateway.mainName
    }

    /// The chosen AII's own Thread: its URL and the file holding the key it wants.
    static func direct(_ thread: String, records: [ThreadRecord], main: AIIHome = .resolved()) -> (url: String, keyFile: String) {
        if let record = records.first(where: { $0.name == thread }) {
            return ("http://127.0.0.1:\(record.threadHTTP)", PrivateFile.path(record.aiiHome.secretFile(for: WeaveIdentity.app)))
        }
        return ("http://127.0.0.1:\(AIIConfig.load(home: main).threadPorts.http)", PrivateFile.path(main.secretFile(for: WeaveIdentity.app)))
    }

    /// Sends the example as another app would: to 127.0.0.1, with Weave's key when the port asks for it.
    static func send(_ example: RequestExample, port: Int, requireSecret: Bool) async -> Result {
        let secret = requireSecret ? (try? AIIHome.resolved().readSecret(for: WeaveIdentity.app)) : nil
        let request = LoopbackHTTP.request(port: port, path: example.path, method: example.method,
                                           body: example.body.map { Data($0.utf8) }, secret: secret, timeout: 60)
        let started = Date()
        do {
            let (data, status) = try await LoopbackHTTP.send(request)
            return Result(status: status, body: pretty(data), milliseconds: Date().timeIntervalSince(started) * 1000)
        } catch {
            return Result(status: 0, body: "Weave's port did not answer: \(FabricOps.message(error)). Is it listening (Settings › Weave's port)?",
                          milliseconds: Date().timeIntervalSince(started) * 1000)
        }
    }

    /// The answer, indented, and cut at a readable length.
    static func pretty(_ data: Data, limit: Int = 4000) -> String {
        let text: String
        if let object = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .withoutEscapingSlashes]) {
            text = String(decoding: pretty, as: UTF8.self)
        } else {
            text = String(decoding: data, as: UTF8.self)
        }
        return text.count > limit ? String(text.prefix(limit)) + "\n…" : text
    }
}
