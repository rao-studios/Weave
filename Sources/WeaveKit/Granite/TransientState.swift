//
//  TransientState.swift
//  WeaveKit
//
//  A Granite state that is never persisted: it mirrors what the runtime knows right now (a loaded
//  model, a run's progress, what Thread holds) and is read again at launch. `GraniteState` is
//  `Codable`, so this codes as an empty object and reads back as the defaults. Nothing durable
//  lives in a transient state.
//

import Foundation
import Granite

public protocol TransientState: GraniteState {}

extension TransientState {
    public init(from decoder: Decoder) throws { self.init() }
    public func encode(to encoder: Encoder) throws { _ = encoder.container(keyedBy: TransientStateNoKeys.self) }
}

enum TransientStateNoKeys: CodingKey {}
