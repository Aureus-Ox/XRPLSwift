//
//  GetLedgerIndexSugar.swift
//
//
//  Created by Denis Angell on 8/21/22.
//

// https://github.com/XRPLF/xrpl.js/blob/main/packages/xrpl/src/sugar/getLedgerIndex.ts

/**
 Returns the index of the most recently validated ledger.
 - parameters:
    - client: The Client used to connect to the ledger.
 - returns
 The most recently validated ledger index.
 */
public func getLedgerIndex(_ client: XrplClient) async throws -> Int {
    let ledgerValidatedRequest = LedgerRequest(ledgerIndex: .string("validated"))
    guard let ledgerResponse = try? await client.request(ledgerValidatedRequest).get() as? BaseResponse<LedgerResponse>,
          let ledgerIndex = ledgerResponse.result?.ledgerIndex
    else {
        return 0
    }

    return ledgerIndex
}
