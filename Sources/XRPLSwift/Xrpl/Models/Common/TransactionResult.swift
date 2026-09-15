//
//  TransactionResult.swift
//  XRPLSwift
//
//  Created by Nicholas LoBue on 3/30/25.
//

import Foundation


public enum TransactionResult: String, Codable {
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
    
    case tefALREADY
    case tefBAD_ADD_AUTH
    case tefBAD_AUTH
    case tefBAD_AUTH_MASTER
    case tefBAD_LEDGER
    case tefBAD_QUORUM
    case tefBAD_SIGNATURE
    case tefCREATED
    case tefEXCEPTION
    case tefFAILURE
    case tefINTERNAL
    case tefINVARIANT_FAILED
    case tefMASTER_DISABLED
    case tefMAX_LEDGER
    case tefNFTOKEN_IS_NOT_TRANSFERABLE
    case tefNO_AUTH_REQUIRED
    case tefNO_TICKET
    case tefNOT_MULTI_SIGNING
    case tefPAST_SEQ
    case tefTOO_BIG
    case tefWRONG_PRIOR
    
    case tecAMM_ACCOUNT
    case tecAMM_UNFUNDED
    case tecAMM_BALANCE
    case tecAMM_EMPTY
    case tecAMM_FAILED
    case tecAMM_INVALID_TOKENS
    case tecAMM_NOT_EMPTY
    case tecCANT_ACCEPT_OWN_NFTOKEN_OFFER
    case tecCLAIM
    case tecCRYPTOCONDITION_ERROR
    case tecDIR_FULL
    case tecDUPLICATE
    case tecDST_TAG_NEEDED
    case tecEMPTY_DID
    case tecEXPIRED
    case tecFAILED_PROCESSING
    case tecFROZEN
    case tecHAS_OBLIGATIONS
    case tecINSUF_RESERVE_LINE
    case tecINSUF_RESERVE_OFFER
    case tecINSUFF_FEE
    case tecINSUFFICIENT_FUNDS
    case tecINSUFFICIENT_PAYMENT
    case tecINSUFFICIENT_RESERVE
    case tecINTERNAL
    case tecINVARIANT_FAILED
    case tecKILLED
    case tecMAX_SEQUENCE_REACHED
    case tecNEED_MASTER_KEY
    case tecNFTOKEN_BUY_SELL_MISMATCH
    case tecNFTOKEN_OFFER_TYPE_MISMATCH
    case tecNO_ALTERNATIVE_KEY
    case tecNO_AUTH
    case tecNO_DST
    case tecNO_DST_INSUF_XRP
    case tecNO_ENTRY
    case tecNO_ISSUER
    case tecNO_LINE
    case tecNO_LINE_INSUF_RESERVE
    case tecNO_LINE_REDUNDANT
    case tecNO_PERMISSION
    case tecNO_REGULAR_KEY
    case tecNO_SUITABLE_NFTOKEN_PAGE
    case tecNO_TARGET
    case tecOBJECT_NOT_FOUND
    case tecOVERSIZE
    case tecOWNERS
    case tecPATH_DRY
    case tecPATH_PARTIAL
    case tecTOO_SOON
    case tecUNFUNDED
    case tecUNFUNDED_ADD
    case tecUNFUNDED_PAYMENT
    case tecUNFUNDED_OFFER
    
    // TODO: - Add utility to match codes from DefinitionJson
}
