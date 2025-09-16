//
//  SubmitSugar.swift
//
//
//  Created by Denis Angell on 8/1/22.
//

// https://github.com/XRPLF/xrpl.js/blob/main/packages/xrpl/src/sugar/submit.ts

import Foundation
import NIO

/// Approximate time for a ledger to close, in milliseconds
let LEDGER_CLOSE_TIME_MILLI: UInt32 = 3000 // swiftlint:disable:this identifier_name
let LEDGER_CLOSE_TIME: UInt32 = 4 // swiftlint:disable:this identifier_name

public enum SubmitTransaction: Codable {
    case tx(Transaction)
    case string(String)
}

extension SubmitTransaction {
    enum AmountCodingError: Error {
        case decoding(String)
    }

    public init(from decoder: Decoder) throws {
        if let value = try? Transaction(from: decoder) {
            self = .tx(value)
            return
        }
        if let value = try? String(from: decoder) {
            self = .string(value)
            return
        }
        throw AmountCodingError.decoding("SubmitTransaction not mapped")
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .tx(let tx):
            try tx.encode(to: encoder)
        case .string(let string):
            try string.encode(to: encoder)
        }
    }
}

public class SubmitOptions {
    public let autofill: Bool?
    public let failHard: Bool?
    public let wallet: Wallet

    public init(
        autofill: Bool?,
        failHard: Bool?,
        wallet: Wallet
    ) {
        self.autofill = autofill
        self.failHard = failHard
        self.wallet = wallet
    }
}

/**
 Submits a signed/unsigned transaction.
 Steps performed on a transaction:
     1. Autofill.
     2. Sign & Encode.
     3. Submit.
 - parameters:
    - client: A Client.
    - transaction: A transaction to autofill, sign & encode, and submit.
    - autofill: If true, autofill a transaction.
    - failHard: If true, and the transaction fails locally, do not retry or relay the transaction to other servers.
    - wallet: A wallet to sign a transaction. It must be provided when submitting an unsigned transaction.
 - returns:
 A promise that contains SubmitResponse.
 - throws:
 RippledError if submit request fails.
 */
func submit(
    _ client: XrplClient,
    _ transaction: Transaction,
    _ autofill: Bool? = false,
    _ failHard: Bool? = false,
    _ wallet: Wallet?
) async throws -> EventLoopFuture<Any> {
    let signedTx = try await getSignedTx(client, transaction, autofill ?? true, wallet)
    return try await submitRequest(client, signedTx, failHard)
}

/**
 Submits a signed/unsigned transaction.
 Steps performed on a transaction:
     1. Autofill.
     2. Sign & Encode.
     3. Submit.
 - parameters:
    - client: A Client.
    - transaction: A transaction to autofill, sign & encode, and submit.
    - autofill: If true, autofill a transaction.
    - failHard: If true, and the transaction fails locally, do not retry or relay the transaction to other servers.
    - wallet: A wallet to sign a transaction. It must be provided when submitting an unsigned transaction.
 - returns:
 A promise that contains SubmitResponse.
 - throws:
 RippledError if submit request fails.
 */
func submit(
    _ client: XrplClient,
    _ transaction: BaseTransaction,
    _ failHard: Bool? = false
) async throws -> EventLoopFuture<Any> {
    return try await submitRequest(client, transaction, failHard)
}

func submit(
    _ client: XrplClient,
    _ transaction: String,
    _ autofill: Bool? = false,
    _ failHard: Bool? = false,
    _ wallet: Wallet?
) async throws -> EventLoopFuture<Any> {
    let signedTx = try await getSignedTx(client, transaction, autofill ?? true, wallet)
    return try await submitRequest(client, signedTx, failHard)
}

/**
 Asynchronously submits a transaction and verifies that it has been included in a
 validated ledger (or has errored/will not be included for some reason).
 See [Reliable Transaction Submission](https://xrpl.org/reliable-transaction-submission.html).
 - parameters:
    - client: A Client.
    - transaction: A transaction to autofill, sign & encode, and submit.
    - autofill: If true, autofill a transaction.
    - failHard: If true, and the transaction fails locally, do not retry or relay the transaction to other servers.
    - wallet: A wallet to sign a transaction. It must be provided when submitting an unsigned transaction.
 - returns:
 A promise that contains TxResponse, that will return when the transaction has been validated.
 */
func submitAndWait(
    _ client: XrplClient,
    _ transaction: BaseTransaction,
    _ failHard: Bool? = false
) async throws -> BaseResponse<SubmitResponse> {
    guard let lastLedger = getLastLedgerSequence(transaction) else {
        throw ValidationError("Transaction must contain a LastLedgerSequence value for reliable submission.")
    }

    let response = try await submitRequest(client, transaction, failHard).get()
    
    guard let result = response as? BaseResponse<SubmitResponse>,
          let transactionJson = try? result.result?.txJson.toJson(),
          let engineResult = result.result?.engineResult,
          transactionJson.contains(where: { $0.key == "hash" }),
          let txHash = transactionJson["hash"] as? String
    else {
        throw ValidationError("Transaction must contain a hash value for reliable submission.")
    }

    _ = try await waitForFinalTransactionOutcome(
        client: client,
        txHash: txHash,
        lastLedger: lastLedger,
        submissionResult: engineResult
    )

    return result
}

// Encodes and submits a signed transaction.
func submitRequest(
    _ client: XrplClient,
    _ signedTransaction: Transaction,
    _ failHard: Bool? = false
    // ) async throws -> EventLoopFuture<SubmitResponse> {
) async throws -> EventLoopFuture<Any> {
    if !isSigned(try signedTransaction.toJson()) {
        throw ValidationError("Transaction must be signed")
    }
    let signedTxEncoded: String = try BinaryCodec.encode(signedTransaction.toJson())
    let request = SubmitRequest(
        txBlob: signedTxEncoded,
        //        failHard: isAccountDelete(transaction: signedTransaction) || failHard!
        failHard: failHard!
    )
    return try await client.request(req: request)!
}

// Encodes and submits a signed transaction.
func submitRequest(
    _ client: XrplClient,
    _ signedTransaction: BaseTransaction,
    _ failHard: Bool? = false
    // ) async throws -> EventLoopFuture<SubmitResponse> {
) async throws -> EventLoopFuture<Any> {
    if !isSigned(try signedTransaction.toJson()) {
        throw ValidationError("Transaction must be signed")
    }
    let signedTxEncoded: String = try BinaryCodec.encode(signedTransaction.toJson())
    let request = SubmitRequest(
        txBlob: signedTxEncoded,
        //        failHard: isAccountDelete(transaction: signedTransaction) || failHard!
        failHard: failHard!
    )
    return try await client.request(req: request)!
}

func submitRequest(
    _ client: XrplClient,
    _ signedTransaction: String,
    _ failHard: Bool? = false
    // ) async throws -> EventLoopFuture<SubmitResponse> {
) async throws -> EventLoopFuture<Any> {
    if !isSigned(signedTransaction) {
        throw ValidationError("Transaction must be signed")
    }

    let signedTxEncoded: String = signedTransaction
    let request = SubmitRequest(
        txBlob: signedTxEncoded,
        //        failHard: isAccountDelete(transaction: signedTransaction) || failHard!
        failHard: failHard ?? false
    )
    return try await client.request(req: request)!
}

/// *
// * The core logic of reliable submission.  This polls the ledger until the result of the
// * transaction can be considered final, meaning it has either been included in a
// * validated ledger, or the transaction"s lastLedgerSequence has been surpassed by the
// * latest ledger sequence (meaning it will never be included in a validated ledger).
// */
//// eslint-disable-next-line max-params, max-lines-per-function -- this function needs to display and do with more information.
 func waitForFinalTransactionOutcome(
  client: XrplClient,
  txHash: String,
  lastLedger: Int,
  submissionResult: String
 ) async throws -> TxResponse {
     // Approximated ledger close time
     sleep(LEDGER_CLOSE_TIME)
     
     let latestLedger = try await client.getLedgerIndex()
     
     if (lastLedger < latestLedger) {
         throw XrplError(
            "The latest ledger sequence \(latestLedger) is greater than the transaction's LastLedgerSequence (\(lastLedger)). Preliminary result: \(submissionResult)"
         )
     }
     
     let txRequest = TxRequest(transaction: txHash)
     let txResponse = try await client.request(txRequest).get()

     if let response = txResponse as? BaseResponse<TxResponse> {
         guard let result = response.result, let validated = result.validated else {
             throw XrplError("Unexpected Tx Result")
         }
    
         if validated {
             return result
         }
         
         return try await waitForFinalTransactionOutcome(
            client: client,
            txHash: txHash,
            lastLedger: lastLedger,
            submissionResult: submissionResult
         )
     } else if let response = txResponse as? ErrorResponse {
         if response.error.contains("txnNotFound") {
             return try await waitForFinalTransactionOutcome(
                client: client,
                txHash: txHash,
                lastLedger: lastLedger,
                submissionResult: submissionResult
             )
         }
         
         throw XrplError("Unexpected Error: \(response.error)")
     } else {
         throw XrplError("Invalid Tx Response")
     }
 }

// checks if the transaction has been signed
func isSigned(_ transaction: String) -> Bool {
    let tx = BinaryCodec.decode(transaction)
    return isSigned(tx)
}

func isSigned(_ transaction: [String: AnyObject]) -> Bool {
    return transaction["SigningPubKey"] != nil || transaction["TxnSignature"] != nil
}

func isSigned(_ transaction: Transaction) -> Bool {
    guard let tx = try? transaction.toJson() else { return false }
    return tx["SigningPubKey"] != nil || tx["TxnSignature"] != nil
}

// initializes a transaction for a submit request
func getSignedTx(
    _ client: XrplClient,
    _ transaction: String,
    _ autofill: Bool = true,
    _ wallet: Wallet?
    // ) async throws -> EventLoopFuture<String> {
) async throws -> String {
    if isSigned(transaction) {
        return transaction
    }

    guard let wallet = wallet else {
        throw ValidationError("Wallet must be provided when submitting an unsigned transaction")
    }

    var tx = BinaryCodec.decode(transaction)
    if autofill {
        tx = try await AutoFillSugar().autofill(client, tx, 0).wait()
    }
    return try wallet.sign(tx, false).txBlob
}

func getSignedTx(
    _ client: XrplClient,
    _ transaction: Transaction,
    _ autofill: Bool = true,
    _ wallet: Wallet?
) async throws -> String {
    if isSigned(transaction) {
        let serializedTx = try BinaryCodec.encode(transaction.toJson())
        return serializedTx
    }

    guard let wallet = wallet else {
        throw ValidationError("Wallet must be provided when submitting an unsigned transaction")
    }
    //    var tx = try transaction.toAny() as! BaseTransaction
    var tx = try transaction.toJson()
    if autofill {
        tx = try await AutoFillSugar().autofill(client, tx, 0).get()
    }
    return try wallet.sign(tx, false).txBlob
}

// checks if there is a LastLedgerSequence as a part of the transaction
func getLastLedgerSequence(_ transaction: String) -> Int? {
    let tx = BinaryCodec.decode(transaction)
    return tx["LastLedgerSequence"] as? Int
}

// checks if there is a LastLedgerSequence as a part of the transaction
func getLastLedgerSequence(_ transaction: Transaction) -> Int? {
    let tx = try? transaction.toJson()
    return tx?["LastLedgerSequence"] as? Int
}

// checks if there is a LastLedgerSequence as a part of the transaction
func getLastLedgerSequence(_ transaction: BaseTransaction) -> Int? {
    return transaction.lastLedgerSequence
}

// checks if the transaction is an AccountDelete transaction
func isAccountDelete(_ transaction: SubmitTransaction) -> Bool {
    //    let tx = transaction is String ? BinaryCodec.decode(transaction) : transaction
    let tx = transaction
    //    return tx.TransactionType == "AccountDelete"
    return false
}
