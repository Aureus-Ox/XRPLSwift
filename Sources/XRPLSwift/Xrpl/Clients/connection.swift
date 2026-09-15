//
//  connection.swift
//
//
//  Created by Denis Angell on 7/27/22.
//

// https://github.com/XRPLF/xrpl.js/blob/main/packages/xrpl/src/client/connection.ts

import Foundation
import NIO
import NIOCore
import WebSocketKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(CoreFoundation)
import CoreFoundation
#endif
import os

// ----------------------------------------------------------------------------------

protocol ConsoleLogDelegate: AnyObject {
    func onUpdate(id: Int, message: String)
}

class ConsoleLog {
    var trace: [[String: AnyObject]] = []
    func push(id: Int, _ message: String) {
        self.trace.append([
            "id": id,
            "message": message
        ] as? [String: AnyObject] ?? [:])
    }
}

// ----------------------------------------------------------------------------------

private let connEventGroup = MultiThreadedEventLoopGroup(numberOfThreads: 4)

private let SECONDS_PER_MINUTE: Double = 60 // swiftlint:disable:this identifier_name
/// JSON-RPC request + heartbeat interval, in seconds (xrpl.js uses 20_000 ms).
private let TIMEOUT_SECONDS: Int = 20
/// Initial TCP/TLS/upgrade budget, in seconds.
private let CONNECTION_TIMEOUT_SECONDS: Int = 10
/// WebSocket protocol ping interval. Keeps reverse-proxies (nginx) from dropping idle sockets.
private let WEBSOCKET_PING_SECONDS: Int64 = 20

public enum WebsocketState: String {
    case closed
    case closing
    case open
}

/**
 ConnectionOptions is the configuration for the Connection class.
 */
public class ConnectionOptions {
    //  trace: Bool? | ((id: string, message: string) => void)
    internal var trace: ConsoleLog?
    public var proxy: String?
    public var proxyAuthorization: String?
    public var authorization: String?
    public var trustedCertificates: [String]?
    public var key: String?
    public var passphrase: String?
    public var certificate: String?
    /// Request timeout in **seconds**.
    public var timeout: Int?
    /// Connect/upgrade timeout in **seconds**.
    public var connectionTimeout: Int = CONNECTION_TIMEOUT_SECONDS
    public var headers: [String: [String: String]]?
}

/**
 ConnectionUserOptions is the user-provided configuration object. All configuration
 is optional, so any ConnectionOptions configuration that has a default value is
 still optional at the point that the user provides it.
 */
public class ConnectionUserOptions: ConnectionOptions {}

/**
 Represents an intentionally triggered web-socket disconnect code.
 WebSocket spec allows 4xxx codes for app/library specific codes.
 See: https://developer.mozilla.org/en-US/docs/Web/API/CloseEvent
 */
public let INTENTIONAL_DISCONNECT_CODE = 4000 // swiftlint:disable:this identifier_name

/**
 Create a new websocket given your URL and optional proxy/certificate configuration.
 - parameters:
 - url: The URL to connect to.
 - config: The configuration options for the WebSocket.
 - returns:
 A Websocket that fits the given configuration parameters.
 */
public func createWebSocket(
    url: String
) -> WebSocketClient? {
    let client = WebSocketClient(eventLoopGroupProvider: .shared(connEventGroup))
    return client
}

/**
 Ws.send(), but promisified.
 - parameters:
 - ws: Websocket to send with.
 - message: Message to send.
 - returns:
 When the message has been sent.
 */
public func websocketSendAsync(
    ws: WebSocket,
    message: String
) async -> EventLoopFuture<Void> {
    let promise = connEventGroup.next().makePromise(of: Void.self)
    ws.send(message, promise: promise)
    return promise.futureResult
}

public protocol ConnectionDelegate: AnyObject {
    func error(code: Int, message: Any, data: Data)
    func connect() async throws -> EventLoopFuture<Any>
    func connected()
    func disconnected(code: Int)
    func ledgerClosed(ledger: Any)
    func transaction(tx: Any)
    func validationReceived(validation: Any)
    func manifestReceived(manifest: Any)
    func peerStatusChange(status: Any)
    func consensusPhase(consensus: Any)
    func pathFind(path: Any)
}

@preconcurrency
public protocol WebsocketResponding: AnyObject {
    func isConnected() async -> Bool
    func connect() async throws -> EventLoopFuture<Any>
    func disconnect() async -> EventLoopFuture<Any?>
    func reconnect() async throws
    func waitUntilConnected(timeoutSeconds: Double) async throws
    func currentState() async -> XRPLConnectionState

    func request<R: BaseRequest>(request: R, timeout: Int?) async throws -> EventLoopFuture<Any>
    func getUrl() async -> String
}

private struct ConnectionWaiter {
    let id: UUID
    let continuation: CheckedContinuation<Void, Error>
    let timeoutTask: Task<Void, Never>
}

/**
 The main Connection class. Responsible for connecting to & managing
 an active WebSocket connection to a XRPL node.
 */
public actor Connection: Sendable, WebsocketResponding {
    var trace: ConsoleLog?

    let url: String?
    var ws: WebSocket?
    private let retryConnectionBackoff = ExponentialBackoff(
        opts: ExponentialBackoffOptions(min: 0.1, max: SECONDS_PER_MINUTE)
    )

    let config: ConnectionOptions
    private let requestManager = RequestManager()
    private let connectionManager = ConnectionManager()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: String(describing: Connection.self)
    )

    private let delegateBox: XRPLConnectionDelegateBox

    /// Client wants a live socket. Cleared only by `disconnect()`.
    private var wantsConnection: Bool = false
    /// True while a close was requested by `disconnect()` / `reconnect()`.
    private var intentionalClose: Bool = false
    private var connectionState: XRPLConnectionState = .disconnected
    private var inFlightConnect: EventLoopPromise<Any>?
    private var reconnectTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var upgradeTimeoutTask: Task<Void, Never>?
    private var stateWaiters: [ConnectionWaiter] = []
    private var upgradeContinuation: CheckedContinuation<Void, Error>?

    /**
     Creates a new Connection object.
     - parameters:
     - ws: URL to connect to.
     - options: Options for the Connection object.
     */
    public init(url: String?, options: ConnectionUserOptions? = nil) {
        self.init(url: url, options: options, delegateBox: XRPLConnectionDelegateBox())
    }

    init(url: String?, options: ConnectionUserOptions? = nil, delegateBox: XRPLConnectionDelegateBox) {
        self.url = url
        self.config = ConnectionOptions()
        self.config.timeout = options?.timeout ?? TIMEOUT_SECONDS
        self.config.connectionTimeout = options?.connectionTimeout ?? CONNECTION_TIMEOUT_SECONDS
        self.config.proxy = options?.proxy
        self.config.authorization = options?.authorization
        self.config.trustedCertificates = options?.trustedCertificates
        self.config.key = options?.key
        self.config.passphrase = options?.passphrase
        self.config.certificate = options?.certificate
        self.config.headers = options?.headers
        self.delegateBox = delegateBox
    }

    func setConnectionDelegate(_ delegate: XRPLConnectionDelegate?) {
        delegateBox.delegate = delegate
    }

    public func currentState() async -> XRPLConnectionState {
        return connectionState
    }

    /**
     Returns whether the websocket is connected.
     - returns:
     Whether the websocket connection is open.
     */
    public func isConnected() async -> Bool {
        return hasLiveSocket()
    }

    private func hasLiveSocket() -> Bool {
        return socketIsOpen() && connectionState == .connected
    }

    /**
     Connects the websocket to the provided URL.
     Waits until the socket is open and handlers are attached (or fails).
     Idempotent: already-connected returns immediately; in-flight joins the same attempt.
     After the first successful `connect()`, unexpected drops auto-reconnect until `disconnect()`.
     */
    public func connect() async throws -> EventLoopFuture<Any> {
        wantsConnection = true

        if hasLiveSocket() {
            return succeededFuture()
        }

        if let inFlight = inFlightConnect {
            try await inFlight.futureResult.get()
            return inFlight.futureResult
        }

        let promise = connEventGroup.next().makePromise(of: Any.self)
        inFlightConnect = promise
        setState(.connecting)

        do {
            try await openSocket()
            promise.succeed("")
            inFlightConnect = nil
            return promise.futureResult
        } catch {
            promise.fail(error)
            inFlightConnect = nil
            notifyFailure(error)
            if wantsConnection {
                scheduleReconnect()
            }
            throw error
        }
    }

    /**
     Disconnect the websocket connection.
     We never expect this method to reject. Even on "bad" disconnects, the websocket
     should still successfully close with the relevant error code returned.
     See https://developer.mozilla.org/en-US/docs/Web/API/CloseEvent for the full list.
     If no open websocket connection exists, resolve with no code (`undefined`).
     - returns:
     A promise containing either `undefined` or a disconnected code, that resolves when the connection is destroyed.
     */
    public func disconnect() async -> EventLoopFuture<Any?> {
        wantsConnection = false
        intentionalClose = true
        clearHeartbeat()
        reconnectTask?.cancel()
        reconnectTask = nil
        upgradeTimeoutTask?.cancel()
        upgradeTimeoutTask = nil
        retryConnectionBackoff.reset()

        await connectionManager.rejectAllAwaiting(error: ConnectionError("Disconnection requested"))
        failStateWaiters(ConnectionError("Disconnection requested"))

        let promise = connEventGroup.next().makePromise(of: Any?.self)
        if ws == nil {
            setState(.disconnected)
            promise.succeed(nil)
            return promise.futureResult
        }

        promise.succeed(1000)
        _ = try? await ws?.close(code: .normalClosure)
        ws = nil
        setState(.disconnected)
        return promise.futureResult
    }

    /**
     Disconnect the websocket, then connect again.
     */
    public func reconnect() async throws {
        wantsConnection = true
        intentionalClose = true
        clearHeartbeat()
        reconnectTask?.cancel()
        reconnectTask = nil
        _ = try? await ws?.close(code: .normalClosure)
        ws = nil
        _ = try await connect().get()
    }

    public func waitUntilConnected(timeoutSeconds: Double = 30) async throws {
        if hasLiveSocket() { return }
        if !wantsConnection {
            _ = try await connect()
            return
        }
        if hasLiveSocket() { return }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let id = UUID()
            let timeoutTask = Task {
                let ns = UInt64(max(timeoutSeconds, 0.05) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
                await self.timeoutWaiter(id)
            }
            stateWaiters.append(ConnectionWaiter(id: id, continuation: cont, timeoutTask: timeoutTask))
        }
    }

    /**
     Sends a request to the rippled server.
     If the client previously called `connect()` and the socket is temporarily down,
     this waits for reconnect rather than immediately throwing `NotConnectedError`.
     */
    public func request<R: BaseRequest>(
        request: R,
        timeout: Int? = nil
    ) async throws -> EventLoopFuture<Any> {
        if !socketIsOpen() {
            if wantsConnection {
                try await waitUntilConnected(timeoutSeconds: Double(timeout ?? config.timeout ?? TIMEOUT_SECONDS))
            }
        }
        guard socketIsOpen(), let ws = self.ws else {
            throw NotConnectedError("Not Connected")
        }

        let timeoutSeconds = timeout ?? self.config.timeout ?? TIMEOUT_SECONDS
        let (id, message, responsePromise) = try self.requestManager.createRequest(
            request: request,
            timeout: timeoutSeconds
        )

        Task {
            let ns = UInt64(timeoutSeconds) * 1_000_000_000
            try? await Task.sleep(nanoseconds: ns)
            await self.timeoutRequest(id: id)
        }

        _ = await websocketSendAsync(ws: ws, message: message)
        return responsePromise
    }

    /**
     Get the Websocket connection URL.
     - returns:
     The Websocket connection URL.
     */
    public func getUrl() async -> String {
        return self.url ?? ""
    }

    // MARK: - Socket open / close

    private func openSocket() async throws {
        if socketIsOpen() {
            setState(.connected)
            return
        }

        guard let url = url else {
            throw ConnectionError("Cannot connect because no server was specified")
        }
        let endpoint = try parseWebsocketURL(url)

        guard let client = createWebSocket(url: url) else {
            throw ConnectionError("Failed to create client")
        }

        let connectTimeout = config.connectionTimeout
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.upgradeContinuation = cont
            self.upgradeTimeoutTask?.cancel()
            self.upgradeTimeoutTask = Task {
                let ns = UInt64(connectTimeout) * 1_000_000_000
                try? await Task.sleep(nanoseconds: ns)
                await self.failUpgrade(TimeoutError("Connection timeout", nil))
            }

            let future = client.connect(
                scheme: endpoint.scheme,
                host: endpoint.host,
                port: endpoint.port,
                path: endpoint.path,
                onUpgrade: { ws in
                    Task {
                        await self.finishUpgrade(ws)
                    }
                }
            )

            future.whenFailure { error in
                Task {
                    await self.failUpgrade(error)
                }
            }
        }
    }

    private func finishUpgrade(_ ws: WebSocket) {
        guard let cont = upgradeContinuation else {
            // Upgrade after timeout/cancel — drop the extra socket.
            _ = ws.close()
            return
        }
        upgradeContinuation = nil
        upgradeTimeoutTask?.cancel()
        upgradeTimeoutTask = nil
        self.ws = ws
        intentionalClose = false
        setHandlers()
        ws.pingInterval = .seconds(WEBSOCKET_PING_SECONDS)
        retryConnectionBackoff.reset()
        startHeartbeat()
        setState(.connected)
        Task {
            await self.connectionManager.resolveAllAwaiting()
        }
        resumeWaitersSuccess()
        logger.info("XRPL websocket connected to \(self.url ?? "", privacy: .public)")
        cont.resume()
    }

    private func failUpgrade(_ error: Error) {
        guard let cont = upgradeContinuation else { return }
        upgradeContinuation = nil
        upgradeTimeoutTask?.cancel()
        upgradeTimeoutTask = nil
        ws = nil
        cont.resume(throwing: error)
    }

    private func handleUnexpectedDisconnect(reason: String, code: Int?) {
        clearHeartbeat()
        try? requestManager.rejectAll(error: DisconnectedError("websocket was closed, \(reason)"))
        ws = nil

        if intentionalClose || !wantsConnection {
            intentionalClose = false
            setState(.disconnected)
            return
        }

        logger.warning("XRPL websocket disconnected (\(reason), code=\(code ?? -1)). Reconnecting.")
        notifyFailure(DisconnectedError("websocket was closed, \(reason)"))
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard wantsConnection else { return }
        guard reconnectTask == nil else { return }

        let delay = retryConnectionBackoff.duration()
        let attempt = retryConnectionBackoff.attempts()
        setState(.reconnecting(attempt: attempt))
        logger.info("XRPL reconnect attempt \(attempt) in \(delay)s")

        reconnectTask = Task {
            let ns = UInt64(max(delay, 0.05) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            await self.runScheduledReconnect()
        }
    }

    private func runScheduledReconnect() async {
        reconnectTask = nil
        guard wantsConnection, !hasLiveSocket(), !Task.isCancelled else { return }
        do {
            _ = try await connect()
        } catch {
            // `connect()` schedules the next attempt on failure.
        }
    }

    // MARK: - Heartbeat

    private func clearHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    private func startHeartbeat() {
        clearHeartbeat()
        let interval = UInt64((config.timeout ?? TIMEOUT_SECONDS) * 1_000_000_000)
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval)
                if Task.isCancelled { break }
                await self.sendHeartbeat()
            }
        }
    }

    private func sendHeartbeat() async {
        guard wantsConnection, socketIsOpen() else { return }
        do {
            let response = try await request(request: PingRequest(), timeout: min(10, config.timeout ?? TIMEOUT_SECONDS))
            _ = try await response.get()
        } catch {
            logger.warning("XRPL heartbeat ping failed: \(error.localizedDescription)")
            if wantsConnection {
                handleUnexpectedDisconnect(reason: "heartbeat failed", code: nil)
            }
        }
    }

    // MARK: - Messages

    /**
     Handler for when messages are received from the server.
     - parameters:
     - message: The message received from the server.
     */
    private func onMessage(data: Data) {
        var dict: [String: AnyObject] = [:]
        do {
            dict = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves) as! [String: AnyObject]
        } catch {
            logger.warning("XRPL bad websocket message: \(error.localizedDescription)")
            return
        }
        guard let type = dict["type"] as? String else {
            return
        }
        if type == "response" {
            do {
                try self.requestManager.handleResponse(response: dict)
            } catch {
                logger.warning("XRPL response handling failed: \(error.localizedDescription)")
            }
        }
    }

    /**
     Handler for when messages are received from the server.
     - parameters:
     - message: The message received from the server.
     */
    private func onMessage(message: String) {
        guard let data: Data = message.data(using: .utf8) else {
            logger.warning("Failed to parse message as UTF-8: \(message)")
            return
        }
        self.onMessage(data: data)
    }

    /**
     Gets the state of the websocket.
     - returns:
     The Websocket"s ready state.
     */
    private var state: WebsocketState {
        return socketIsOpen() ? WebsocketState.open : WebsocketState.closed
    }

    /**
     Returns whether the server should be connected.
     - returns:
     Whether the server should be connected.
     */
    private var shouldBeConnected: Bool {
        return wantsConnection
    }

    private func setWebSocket(ws: WebSocket?) {
        self.ws = ws
    }

    private func socketIsOpen() -> Bool {
        guard let ws = ws else { return false }
        return !ws.isClosed
    }

    private func setHandlers() {
        self.ws?.onText({ _, message in
            await self.onMessage(message: message)
        })

        self.ws?.onBinary({ _, message in
            let data = Data(buffer: message)
            await self.onMessage(data: data)
        })

        _ = self.ws?.onClose.always { result in
            Task {
                let reason: String
                switch result {
                case .success:
                    reason = "close"
                case .failure(let error):
                    reason = error.localizedDescription
                }
                await self.handleUnexpectedDisconnect(reason: reason, code: nil)
            }
        }
    }

    // MARK: - Waiters / notify

    private func setState(_ state: XRPLConnectionState) {
        guard connectionState != state else { return }
        connectionState = state
        let box = delegateBox
        Task { @MainActor in
            box.delegate?.xrplConnection(didChangeState: state)
        }
        if state == .connected {
            resumeWaitersSuccess()
        }
    }

    private func notifyFailure(_ error: Error) {
        let box = delegateBox
        Task { @MainActor in
            box.delegate?.xrplConnection(didFailWithError: error)
        }
    }

    private func resumeWaitersSuccess() {
        let waiters = stateWaiters
        stateWaiters.removeAll()
        for waiter in waiters {
            waiter.timeoutTask.cancel()
            waiter.continuation.resume()
        }
    }

    private func failStateWaiters(_ error: Error) {
        let waiters = stateWaiters
        stateWaiters.removeAll()
        for waiter in waiters {
            waiter.timeoutTask.cancel()
            waiter.continuation.resume(throwing: error)
        }
    }

    private func timeoutWaiter(_ id: UUID) {
        guard let index = stateWaiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = stateWaiters.remove(at: index)
        waiter.timeoutTask.cancel()
        waiter.continuation.resume(throwing: TimeoutError("Connection timeout", nil))
    }

    private func timeoutRequest(id: Int) {
        try? requestManager.reject(id: id, error: TimeoutError("Timeout Error"))
    }

    private func succeededFuture() -> EventLoopFuture<Any> {
        let promise = connEventGroup.next().makePromise(of: Any.self)
        promise.succeed("")
        return promise.futureResult
    }
}
