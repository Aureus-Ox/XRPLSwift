//
//  TransactionResult.swift
//  XRPLSwift
//
//  Created by Nicholas LoBue on 3/30/25.
//

import Foundation


public enum TransactionResult: Codable {
    case tesSUCCESS
    
    case terINSUF_FEE_B
    case terLAST
    case terNO_ACCOUNT
    case terNO_AMM
    case terNO_AUTH
    case terNO_LINE
    case terNO_RIPPLE
    case terOWNERS
    case terPRE_SEQ
    case terPRE_TICKET
    case terQUEUED
    case terRETRY
    case terSUBMITTED
    
    case temBAD_AMM_TOKENS
    case temBAD_AMOUNT
    case temBAD_AUTH_MASTER
    case temBAD_CURRENCY
    case temBAD_EXPIRATION
    case temBAD_FEE
    case temBAD_ISSUER
    case temBAD_LIMIT
    case temBAD_NFTOKEN_TRANSFER_FEE
    case temBAD_OFFER
    case temBAD_PATH
    case temBAD_PATH_LOOP
    case temBAD_SEND_XRP_LIMIT
    case temBAD_SEND_XRP_MAX
    case temBAD_SEND_XRP_NO_DIRECT
    case temBAD_SEND_XRP_PARTIAL
    case temBAD_SEND_XRP_PATHS
    case temBAD_SEQUENCE
    case temBAD_SIGNATURE
    case temBAD_SRC_ACCOUNT
    case temBAD_TRANSFER_RATE
    case temCANNOT_PREAUTH_SELF
    case temDST_IS_SRC
    case temDST_NEEDED
    case temINVALID
    case temINVALID_COUNT
    case temINVALID_FLAG
    case temMALFORMED
    case temREDUNDANT
    case temRIPPLE_EMPTY
    case temBAD_WEIGHT
    case temBAD_SIGNER
    case temBAD_QUORUM
    case temUNCERTAIN
    case temUNKNOWN
    case temDISABLED
    
    case telBAD_DOMAIN
    case telBAD_PATH_COUNT
    case telBAD_PUBLIC_KEY
    case telCAN_NOT_QUEUE
    case telCAN_NOT_QUEUE_BALANCE
    case telCAN_NOT_QUEUE_BLOCKS
    case telCAN_NOT_QUEUE_BLOCKED
    case telCAN_NOT_QUEUE_FEE
    case telCAN_NOT_QUEUE_FULL
    case telFAILED_PROCESSING
    case telINSUF_FEE_P
    case telLOCAL_ERROR
    case telNETWORK_ID_MAKES_TX_NON_CANONICAL
    case telNO_DST_PARTIAL
    case telREQUIRES_NETWORK_ID
    case telWRONG_NETWORK
}
