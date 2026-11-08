//
//  main.swift
//  Weave
//
//  Launched directly via NSApplication (no storyboard, no @main App), as Veil and Craft are.
//  Top-level code runs on the main thread; `assumeIsolated` states that to the compiler.
//
//  Arguments: --self-test (a headless exercise of the fabric and the port against a scratch AII
//  home, prints results, exits 0/1), --e2e <folder> (the whole fabric against this Mac's AII:
//  see EndToEnd.swift), --demo seed|clear (the README's demo fabric: Demo.swift),
//  --explore=<name> and --query=<text> (open on that AII, run that search), --window=<w>x<h>,
//  --mode=<fabric|explorer|search|settings> (open on a page).
//

import AppKit

let arguments = CommandLine.arguments

MainActor.assumeIsolated {
    let app = NSApplication.shared
    if arguments.contains("--demo") {
        app.setActivationPolicy(.prohibited)
        Task { @MainActor in exit(await Demo.run(arguments: arguments)) }
        app.run()
    } else if arguments.contains("--e2e") {
        app.setActivationPolicy(.prohibited)
        Task { @MainActor in exit(await EndToEnd.run(arguments: arguments)) }
        app.run()
    } else if arguments.contains("--self-test") {
        app.setActivationPolicy(.prohibited)
        Task { @MainActor in
            let code = await SelfTest.run(arguments: arguments)
            exit(code)
        }
        app.run()
    } else {
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
