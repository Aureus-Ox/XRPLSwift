//
//  WebsocketURL.swift
//  XRPLSwift
//

import Foundation

struct WebsocketEndpoint: Equatable {
    let scheme: String
    let host: String
    let port: Int
    let path: String
}

/// Parse a rippled/clio websocket URL.
/// Default ports: `wss` → 443, `ws` → 80. Empty path becomes `/`.
func parseWebsocketURL(_ url: String) throws -> WebsocketEndpoint {
    guard let uri = URL(string: url),
          let scheme = uri.scheme?.lowercased(),
          let host = uri.host,
          !host.isEmpty else {
        throw ConnectionError("Connection: invalid url")
    }

    guard scheme == "ws" || scheme == "wss" else {
        throw ConnectionError("Connection: invalid url scheme (expected ws:// or wss://)")
    }

    let port = uri.port ?? (scheme == "ws" ? 80 : 443)
    var path = uri.path.isEmpty ? "/" : uri.path
    if let query = uri.query, !query.isEmpty {
        path += "?" + query
    }

    return WebsocketEndpoint(scheme: scheme, host: host, port: port, path: path)
}

func isValidRippledWebsocketURL(_ url: String) -> Bool {
    let lower = url.lowercased()
    return lower.hasPrefix("wss://")
        || lower.hasPrefix("ws://")
        || lower.hasPrefix("wss+unix://")
        || lower.hasPrefix("ws+unix://")
}
