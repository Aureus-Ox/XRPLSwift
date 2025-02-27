//
//  SetupClient.swift
//
//
//  Created by Denis Angell on 8/18/22.
//

// https://github.com/XRPLF/xrpl.js/blob/main/packages/xrpl/test/setupClient.test.ts

import XCTest
@testable import XRPLSwift

public class RippledMockTester: XCTestCase {
    internal var mockRippled: MockRippledSocket!
    public var _mockedServerPort: Int = 0
    public var client: XrplClient!

    public var wallet: Wallet!

    public override func setUp() {
        self.mockRippled = MockRippledSocket(port: 9999)
        self.mockRippled.start()
        self._mockedServerPort = 9999
        self.client = try! XrplClient(server: "ws://localhost:\(9999)")
        
        Task {
            _ = try await self.client.connect().get()
        }

        // Await connection - Really shouldn't be doing this but keeping for now
        sleep(1)
    }

    public override func tearDown() {
        Task {
            await self.client.disconnect()
        }

        // Await disconnect - Really shouldn't be doing this but keeping for now
        sleep(1)
        self.mockRippled.tearDown()
    }
}

struct MockAO {
    public var normal: String = "rf1BiGeXwwQoi8Z2ueFYTEXSwuJYfV2Jpn"
}

final class MockRippled1: XCTestCase {
    public static let account_objects: MockAO = MockAO()

}
