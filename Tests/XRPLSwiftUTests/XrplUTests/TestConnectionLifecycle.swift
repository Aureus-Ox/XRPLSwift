//
//  TestWebsocketURL.swift
//  XRPLSwift
//

import XCTest
@testable import XRPLSwift

final class TestWebsocketURL: XCTestCase {

    func testParsesWssDefaultPortAndPath() throws {
        let endpoint = try parseWebsocketURL("wss://xrpl.oxenflow.io")
        XCTAssertEqual(endpoint.scheme, "wss")
        XCTAssertEqual(endpoint.host, "xrpl.oxenflow.io")
        XCTAssertEqual(endpoint.port, 443)
        XCTAssertEqual(endpoint.path, "/")
    }

    func testParsesExplicitRippledPort() throws {
        let endpoint = try parseWebsocketURL("wss://s.devnet.rippletest.net:51233")
        XCTAssertEqual(endpoint.port, 51233)
        XCTAssertEqual(endpoint.host, "s.devnet.rippletest.net")
    }

    func testParsesWsDefaultPort() throws {
        let endpoint = try parseWebsocketURL("ws://127.0.0.1")
        XCTAssertEqual(endpoint.scheme, "ws")
        XCTAssertEqual(endpoint.port, 80)
    }

    func testRejectsHttp() {
        XCTAssertThrowsError(try parseWebsocketURL("https://xrpl.oxenflow.io"))
    }

    func testRejectsEmpty() {
        XCTAssertThrowsError(try parseWebsocketURL(""))
    }

    func testValidRippledWebsocketURL() {
        XCTAssertTrue(isValidRippledWebsocketURL("wss://xrpl.oxenflow.io"))
        XCTAssertTrue(isValidRippledWebsocketURL("ws://localhost:6006"))
        XCTAssertFalse(isValidRippledWebsocketURL("https://s.altnet.rippletest.net:51234/"))
        XCTAssertFalse(isValidRippledWebsocketURL("www.ripple.com"))
    }
}

final class TestConnectionLifecycle: XCTestCase {

    func testStartsDisconnected() async {
        let connection = Connection(url: "wss://xrpl.oxenflow.io")
        let connected = await connection.isConnected()
        let state = await connection.currentState()
        XCTAssertFalse(connected)
        XCTAssertEqual(state, .disconnected)
    }

    func testWaitUntilConnectedTimesOutOnUnreachableHost() async {
        let options = ConnectionUserOptions()
        options.connectionTimeout = 1
        let connection = Connection(url: "wss://127.0.0.1:1", options: options)
        do {
            try await connection.waitUntilConnected(timeoutSeconds: 1.5)
            XCTFail("expected timeout or connection error")
        } catch {
            XCTAssertTrue(error is XrplError)
        }
        let connected = await connection.isConnected()
        XCTAssertFalse(connected)
        _ = await connection.disconnect()
    }

    func testClientRejectsNonWebsocketURL() {
        XCTAssertThrowsError(try XrplClient(server: "https://s.altnet.rippletest.net:51234/"))
        XCTAssertNoThrow(try XrplClient(server: "wss://xrpl.oxenflow.io"))
    }

    func testRequestWithoutConnectThrows() async {
        let connection = Connection(url: "wss://xrpl.oxenflow.io")
        do {
            _ = try await connection.request(request: PingRequest())
            XCTFail("expected NotConnectedError")
        } catch {
            XCTAssertTrue(error is XrplError)
        }
    }
}
