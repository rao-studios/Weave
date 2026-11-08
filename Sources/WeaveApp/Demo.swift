//
//  Demo.swift
//  Weave
//
//  `Weave --demo seed` / `Weave --demo clear`: the README's screenshots need a fabric with work in
//  it. Seed spawns three AIIs into Weave's folder (alpha and beta extracting graphs on device,
//  gamma on keywords), starts them woven into the main AII, files three related notes into each
//  (the loom, the engine, the notes: one story across three partitions), waits for the graphs,
//  and exits with the Threads running. Clear stops and removes them.
//  Used by scripts/art/readme-shots.sh.
//

import Foundation
import Granite
import WeaveKit

enum Demo {
    static let names = ["alpha", "beta", "gamma"]

    static let notes: [String: (label: String, notes: [(String, String)])] = [
        "alpha": ("Textile archive", [
            ("jacquard", "The Jacquard loom, patented by Joseph Marie Jacquard in 1804, reads a chain of punched cards; each card lifts the warp threads for one pass of the shuttle, so a pattern becomes a program."),
            ("lyon", "In the silk workshops of Lyon the card chain for a single brocade could run to thousands of cards, and weavers mended the chains as carefully as the cloth."),
            ("portrait", "A portrait of Jacquard woven in silk in 1839 took about 24,000 punched cards. Charles Babbage owned a copy and showed it to visitors."),
        ]),
        "beta": ("Engines", [
            ("analytical", "Charles Babbage designed the Analytical Engine in 1837 to take its instructions on punched cards borrowed from the Jacquard loom."),
            ("store-mill", "The Analytical Engine separated the store, which held numbers, from the mill, which operated on them: memory and processor."),
            ("hollerith", "Herman Hollerith's tabulating machines read punched cards to count the 1890 United States census in months instead of years."),
        ]),
        "gamma": ("Lovelace notes", [
            ("weaves", "Ada Lovelace wrote in 1843 that the Analytical Engine weaves algebraic patterns just as the Jacquard loom weaves flowers and leaves."),
            ("note-g", "Her Note G set out a method for the engine to compute Bernoulli numbers, often called the first published computer program."),
            ("music", "Lovelace imagined the engine composing music once the rules of harmony were expressed in its notation."),
        ]),
    ]

    @MainActor
    static func run(arguments: [String]) async -> Int32 {
        let action = arguments.firstIndex(of: "--demo").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil } ?? "seed"
        let app = WeaveAppRoot.shared
        await app.awaitSettingsLoaded()
        let root = app.settings.state.rootFolder
        let fabric = app.fabric, host = app.host
        do {
            try await fabric.scan(root: root)
            if action == "clear" {
                for name in names where fabric.state.record(name) != nil {
                    try await fabric.remove(name)
                    print("removed \(name)")
                }
                return 0
            }
            let target = try await host.select(.main, root: root)
            for name in names {
                if fabric.state.record(name) == nil {
                    _ = try await fabric.spawn(name: name, graphBackend: name == "gamma" ? "keyword" : "mlx")
                }
                try await fabric.start(name, mothership: target.sewnPorts)
                print("\(name) up")
            }
            _ = await poll(300) {
                await fabric.tick()
                await MainQueue.flush()
                return fabric.state.threads.allSatisfy { fabric.state.embedder[$0.name]?.phase == .ready }
            }
            for name in names {
                guard let record = fabric.state.record(name), let set = notes[name] else { continue }
                let client = try ThreadHTTPClient.forHome(record.aiiHome, port: record.threadHTTP)
                for (title, text) in set.notes {
                    _ = try await client.deposit(text, name: title, groupID: "weave-\(name)", groupLabel: set.label)
                }
                print("\(name): filed \(set.notes.count) notes into \(set.label)")
            }
            // Every note indexed, and the on-device graphs: alpha's and beta's readings have related something.
            _ = await poll(420) {
                await fabric.tick()
                await MainQueue.flush()
                return names.allSatisfy { (fabric.state.counts[$0]?.documents ?? 0) >= (notes[$0]?.notes.count ?? 0) }
                    && ["alpha", "beta"].allSatisfy { (fabric.state.counts[$0]?.relationships ?? 0) > 0 }
            }
            for name in names {
                let c = fabric.state.counts[name]
                print("\(name): \(c?.documents ?? 0) documents, \(c?.entities ?? 0) entities, \(c?.relationships ?? 0) relationships")
            }
            HostService.shutdownSync(stopSpawned: false, records: [])
            return 0
        } catch {
            print("demo: \(FabricOps.message(error))")
            HostService.shutdownSync(stopSpawned: false, records: [])
            return 1
        }
    }

    @MainActor
    private static func poll(_ seconds: Int, _ condition: () async -> Bool) async -> Bool {
        for _ in 0..<seconds {
            if await condition() { return true }
            try? await TaskSleep.seconds(1)
        }
        return false
    }
}
