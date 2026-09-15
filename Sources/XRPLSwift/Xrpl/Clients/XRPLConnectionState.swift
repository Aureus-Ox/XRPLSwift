//
//  XRPLConnectionState.swift
//  XRPLSwift
//
//  Connection lifecycle surface for clients (OxenFlow, other iOS/macOS apps).
//  The package owns reconnect + heartbeat; apps observe state instead of polling.
//

import Foundation

/// High-level XRPL node websocket lifecycle.
public enum XRPLConnectionState: Equatable, Sendable {
    /// No live socket. Either never connected, or `disconnect()` was called.
    case disconnected
    /// TCP/TLS/websocket upgrade in progress (including the first attempt).
    case connecting
    /// Socket is open and handlers are attached. RPC may be sent.
    case connected
    /// Unexpected drop; package will retry with exponential backoff.
    case reconnecting(attempt: Int)

    public var isReady: Bool {
        if case .connected = self { return true }
        return false
    }
}

/// Observe XRPL node connection changes. Callbacks are delivered on the main actor.
public protocol XRPLConnectionDelegate: AnyObject {
    func xrplConnection(didChangeState state: XRPLConnectionState)
    func xrplConnection(didFailWithError error: Error)
}

public extension XRPLConnectionDelegate {
    func xrplConnection(didFailWithError error: Error) {}
}

/// Shared box so `XrplClient` can set a delegate without racing the `Connection` actor.
final class XRPLConnectionDelegateBox: @unchecked Sendable {
    weak var delegate: XRPLConnectionDelegate?
}
