//
//  AccountReserveSugar.swift
//  XRPLSwift
//
//  Created by Nicholas LoBue on 3/31/25.
//

import Foundation


/**
 Calculates the current account reserve for the ledger.
 Note: This is a public API that can be called directly.
 - parameters:
    - client: The Client used to connect to the ledger.
    - cushion: The fee cushion to use.
 - returns:
 The transaction fee.
 */
public func getReserveXrp(
    _ client: XrplClient,
    _ cushion: Double? = nil
) async throws -> Double {
    let feeCushion = cushion ?? client.feeCushion

    let request = ServerInfoRequest()

    guard await client.isConnected() else { throw XrplError("Not Connected") }
    
    let response = try await client.request(request).get()
    guard let response = response as? BaseResponse<ServerInfoResponse> else { throw XrplError("Invalid Response") }
    guard let result = response.result else { throw XrplError("Invalid Result") }

    let serverInfo = result.info
    guard let baseReserve = serverInfo.validatedLedger?.reserveBaseXrp else {
        throw XrplError("Xrp: Could not get base_fee_xrp from server_info")
    }

    return baseReserve
}

