//
//  LoopbackHTTP.swift
//  WeaveKit
//
//  The one place Weave builds and sends a request to a server on this Mac (a Thread, a Sewn):
//  Weave's secret in X-Ambient-Secret, over a session with no proxy, cache or cookies.
//  LOOPBACK ONLY: `send` refuses any other host before a byte leaves (Veil's LoopbackHTTP).
//

import Foundation

public enum WeaveHTTPError: Error, Equatable, LocalizedError {
    case notLoopback
    case status(Int, String)
    case decoding(String)
    case noSecret

    public var errorDescription: String? {
        switch self {
        case .notLoopback: return "Weave only talks to servers on this Mac."
        case .status(let code, let body): return "HTTP \(code)\(body.isEmpty ? "" : ": \(body.prefix(240))")"
        case .decoding(let detail): return "Unexpected answer: \(detail)"
        case .noSecret: return "No Weave secret in that AII's home."
        }
    }

    public var statusCode: Int? {
        if case .status(let code, _) = self { return code }
        return nil
    }
}

public enum LoopbackHTTP {
    public static let host = "127.0.0.1"

    public static func request(port: Int, path: String, method: String = "POST", body: Data? = nil, secret: String?,
                               timeout: TimeInterval = 30) -> URLRequest {
        var request = URLRequest(url: URL(string: "http://\(host):\(port)\(path)")!)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let secret { request.setValue(secret, forHTTPHeaderField: StackSecret.headerName) }
        return request
    }

    @Sendable
    public static func send(_ request: URLRequest) async throws -> (Data, Int) {
        guard let host = request.url?.host, StackSecret.isLoopback(host: host) else { throw WeaveHTTPError.notLoopback }
        let (data, response) = try await session.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    /// Sends, requires a 2xx, and decodes `T`.
    public static func json<T: Decodable>(_ type: T.Type, _ request: URLRequest,
                                          transport: @Sendable (URLRequest) async throws -> (Data, Int) = LoopbackHTTP.send) async throws -> T {
        let (data, status) = try await transport(request)
        guard (200..<300).contains(status) else { throw WeaveHTTPError.status(status, String(decoding: data, as: UTF8.self)) }
        do { return try decoder.decode(T.self, from: data) }
        catch { throw WeaveHTTPError.decoding(String(describing: error)) }
    }

    public static func encode<T: Encodable>(_ value: T) -> Data { (try? encoder.encode(value)) ?? Data("{}".utf8) }

    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    /// Dates arrive as ISO 8601 strings or as seconds; either decodes.
    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let seconds = try? container.decode(Double.self) { return Date(timeIntervalSinceReferenceDate: seconds) }
            let text = try container.decode(String.self)
            let full = ISO8601DateFormatter()
            full.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = full.date(from: text) ?? ISO8601DateFormatter().date(from: text) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "not a date: \(text)")
        }
        return decoder
    }()

    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.connectionProxyDictionary = [:]
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForResource = 120
        return URLSession(configuration: configuration)
    }()
}
