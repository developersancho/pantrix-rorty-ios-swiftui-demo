//
//  RickMortyClient.swift
//  PantrixRortySwiftUI
//
//  The app's only HTTP client. This is where this demo differs from the UIKit one: no Alamofire,
//  no `PantrixEventMonitor` — just `URLSession`, obtained from the SDK so every request is reported.
//

import Foundation
import Pantrix

/// URLSession-backed client for the Rick & Morty API.
///
/// ## The one line that matters
///
/// `Pantrix.instrumentedSession()` returns a normal `URLSession` whose delegate is a transparent
/// proxy — observe-only, so TLS pinning, cookies, cache and streaming are untouched and requests are
/// never re-issued. Everything below is ordinary networking that has never heard of Pantrix.
///
/// **It is created once and reused.** Each call builds a fresh delegate-backed session, and
/// `URLSession` retains its delegate until invalidated — a session per request leaks both.
///
/// ## What this path does and does not capture
///
/// Captured automatically: method, url, status, timings, request/response headers, request body,
/// plus `failureReason` / `failureDescription` / `networkProtocol` / `dnsAddress` — and **failed
/// requests**, which the Alamofire monitor drops entirely (it needs a response to build an event).
///
/// **Not captured: the response body.** Apple only hands the body to a data delegate for
/// delegate-based tasks; for completion-handler and `async`/`await` tasks it never arrives. Since
/// this client uses `session.data(for:)`, every response body here is absent by construction. That
/// is not a bug to work around silently — the Lab screen shows `Pantrix.trackHttp(responseBody:)` as
/// the deliberate way to attach one, and the demo's README explains the trade.
final class RickMortyClient: Sendable {

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL) {
        self.baseURL = baseURL
        self.session = Pantrix.instrumentedSession()
        self.decoder = JSONDecoder()
    }

    // MARK: - Requests

    /// A page of `T`, from a path plus query.
    func page<T: Decodable>(_ path: String, query: [String: String?]) async throws -> PageDto<T> {
        try await get(url(path: path, query: query))
    }

    /// A page of `T` from an absolute URL the API returned. Used verbatim so the caller's filters,
    /// already encoded in it, cannot be lost.
    func page<T: Decodable>(absolute: String) async throws -> PageDto<T> {
        guard let url = URL(string: absolute) else { throw ClientError.badURL(absolute) }
        return try await get(url)
    }

    /// Batch fetch by id.
    ///
    /// The API has a shape quirk worth knowing: `/character/1` returns an **object**, while
    /// `/character/1,2` returns an **array**. Decoding the single-id response as an array fails, so
    /// one id is routed through the object endpoint and wrapped.
    func byIds<T: Decodable>(_ path: String, ids: [Int]) async throws -> [T] {
        guard !ids.isEmpty else { return [] }
        if ids.count == 1 {
            let one: T = try await get(url(path: "\(path)/\(ids[0])", query: [:]))
            return [one]
        }
        let joined = ids.map(String.init).joined(separator: ",")
        return try await get(url(path: "\(path)/\(joined)", query: [:]))
    }

    // MARK: - Plumbing

    private func url(path: String, query: [String: String?]) -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        // Sorted so the same logical request always produces the same URL — otherwise the HTTP
        // events for one screen look like several different endpoints in the dashboard.
        let items = query
            .compactMapValues { $0 }
            .filter { !$0.value.isEmpty }
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        components.queryItems = items.isEmpty ? nil : items
        return components.url!
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        do {
            let (data, response) = try await session.data(for: URLRequest(url: url))
            guard let http = response as? HTTPURLResponse else {
                throw ClientError.notHTTP
            }
            guard (200..<300).contains(http.statusCode) else {
                throw ClientError.status(http.statusCode)
            }
            return try decoder.decode(T.self, from: data)
        } catch {
            // Report and rethrow. The request itself is already tracked by the instrumented session;
            // this adds the app's own context (which endpoint) to a handled exception.
            Pantrix.trackException(error, attributes: ["endpoint": url.path])
            throw error
        }
    }
}

enum ClientError: LocalizedError {
    case badURL(String)
    case notHTTP
    case status(Int)

    var errorDescription: String? {
        switch self {
        case let .badURL(raw): return "Malformed URL: \(raw)"
        case .notHTTP: return "Response was not HTTP."
        case let .status(code): return code == 404 ? "No results." : "Request failed (\(code))."
        }
    }

    /// 404 is the API's "nothing matched this filter" answer, not a failure to show as an error.
    var isNotFound: Bool {
        if case let .status(code) = self { return code == 404 }
        return false
    }
}
