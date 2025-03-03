//
//  PrivateKey.swift
//  HDWalletKit
//
//  Created by Pavlo Boiko on 10/4/18.
//  Copyright © 2018 Essentia. All rights reserved.
//

import CryptoSwift
import Foundation
import secp256k1
#if os(Linux)
import Glibc
#endif

// swiftlint:disable all

enum PrivateKeyType {
    case hd
    case nonHd
}

internal struct PrivateKey {
    internal let raw: Data
    internal let chainCode: Data
    internal let index: UInt32
    internal let coin: Coin
    private var keyType: PrivateKeyType

    internal init(seed: Data, coin: Coin) {
        let output = try! Data(CryptoSwift.HMAC(key: Array("Bitcoin seed".data(using: .ascii)!), variant: .sha512).authenticate(Array(seed)))
        self.raw = output[0..<32]
        self.chainCode = output[32..<64]
        self.index = 0
        self.coin = coin
        self.keyType = .hd
    }

    private init(privateKey: Data, chainCode: Data, index: UInt32, coin: Coin) {
        self.raw = privateKey
        self.chainCode = chainCode
        self.index = index
        self.coin = coin
        self.keyType = .hd
    }

    internal var publicKey: Data {
        var _data = raw
        let ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN))!
        let masterPublicKey = try! SECP256K1.derivePublicKey(ctx: ctx, secretKey: _data.getPointer())
        // TODO: IDK WHY I HAVE TO DO THIS
        _ = _data.getPointer()
        let data = Data(masterPublicKey.compressed)
        secp256k1_context_destroy(ctx)
        return data
    }

    internal func wifCompressed() -> String {
        var data = Data()
        data += Data([coin.wifAddressPrefix])
        data += raw
        data += Data([UInt8(0x01)])
        data += data.sha256().sha256().prefix(4)
        return String(base58Encoding: data)
    }

    internal func get() -> String {
        switch self.coin {
        case .bitcoin: fallthrough
        case .litecoin: fallthrough
        case .dash: fallthrough
        case .bitcoinCash:
            return self.wifCompressed()
        case .ethereum:
            return self.raw.toHexString()
        }
    }

    internal func derived(at node: DerivationNode) -> PrivateKey {
        guard keyType == .hd else { fatalError() }
        let edge: UInt32 = 0x80000000
        guard (edge & node.index) == 0 else { fatalError("Invalid child index") }

        var data = Data()
        switch node {
        case .hardened:
            data += Data([UInt8(0)])
            data += raw
        case .notHardened:
            var _data = raw
            let ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN))!
            let pk = try! SECP256K1.derivePublicKey(ctx: ctx, secretKey: _data.getPointer())
            data += try! Data(pk.compressed)
            // TODO: IDK WHY I HAVE TO DO THIS
            _ = _data.getPointer()
            secp256k1_context_destroy(ctx)
        }

        #if os(Linux)
        let derivingIndex = Glibc.ntohl(node.hardens ? (edge | node.index) : node.index)
        #else
        let derivingIndex = CFSwapInt32BigToHost(node.hardens ? (edge | node.index) : node.index)
        #endif
        data += derivingIndex.data

        let digest = try! Data(HMAC.init(key: Array(chainCode), variant: .sha512).authenticate(Array(data)))
        let factor = BInt(data: digest[0..<32])

        let curveOrder = BInt(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141")!
        let derivedPrivateKey = ((BInt(data: raw) + factor) % curveOrder).data
        let derivedChainCode = digest[32..<64]
        return PrivateKey(
            privateKey: derivedPrivateKey,
            chainCode: derivedChainCode,
            index: derivingIndex,
            coin: coin
        )
    }
}

private extension Data {
    mutating func getPointer() -> UnsafeMutablePointer<UInt8> {
        return self.withUnsafeMutableBytes { (bytePtr) in
            bytePtr.bindMemory(to: UInt8.self).baseAddress!
        }
    }
}
