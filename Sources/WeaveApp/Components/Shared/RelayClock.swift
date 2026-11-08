//
//  RelayClock.swift
//  Weave
//
//  Relay-driven re-renders are debounced 0.2 s by Granite's shared container: too slow for a page
//  switch or a text field. A view that must keep up holds a clock on the services it reads; the
//  clock follows each service's own change signal, throttled to a frame (Veil's RelayClock).
//

import Combine
import Granite
import SwiftUI

@MainActor
final class RelayClock: ObservableObject {
    private var bag = Set<AnyCancellable>()

    init(_ signals: [AnyPublisher<Void, Never>]) {
        Publishers.MergeMany(signals)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)
    }

    static func on<S: GraniteService>(_ type: S.Type) -> AnyPublisher<Void, Never> {
        Relay<S>().relay.objectWillChange.map { _ in () }.eraseToAnyPublisher()
    }
}
