;; NFT Royalty Marketplace: A decentralized marketplace for NFTs with royalty enforcement
;; Author: Claude
;; Version: 1.0

;; Error Constants
(define-constant ERR-NOT-AUTHORIZED (err u101))
(define-constant ERR-NOT-OWNER (err u102))
(define-constant ERR-NFT-ALREADY-LISTED (err u103))
(define-constant ERR-NFT-NOT-LISTED (err u104))
(define-constant ERR-INSUFFICIENT-FUNDS (err u105))
(define-constant ERR-LISTING-EXPIRED (err u106))
(define-constant ERR-LISTING-NOT-ACTIVE (err u107))
(define-constant ERR-INVALID-PRICE (err u108))
(define-constant ERR-INVALID-ROYALTY (err u109))
(define-constant ERR-NFT-TRANSFER-FAILED (err u110))
(define-constant ERR-STX-TRANSFER-FAILED (err u111))
(define-constant ERR-COLLECTION-ALREADY-REGISTERED (err u112))
(define-constant ERR-COLLECTION-NOT-REGISTERED (err u113))
(define-constant ERR-INVALID-EXPIRY (err u114))
(define-constant ERR-SAME-OWNER (err u115))
(define-constant ERR-OFFER-NOT-FOUND (err u116))
(define-constant ERR-OFFER-EXPIRED (err u117))
(define-constant ERR-INSUFFICIENT-OFFER (err u118))

;; Other Constants
(define-constant MARKETPLACE-FEE-DENOMINATOR u1000) ;; Fee denominator for percentage calculation
(define-constant MAX-ROYALTY u200) ;; Maximum royalty 20%
(define-constant DEFAULT-EXPIRY u10000) ;; Default listing expiry in blocks

;; Data Structures

;; NFT Collection data
(define-map collections
  { contract-address: principal }
  {
    name: (string-ascii 64),
    creator: principal,
    royalty-rate: uint, ;; out of 1000
    verified: bool,
    registered-by: principal,
    registration-height: uint
  }
)

;; NFT Listing
(define-map listings
  { contract-address: principal, token-id: uint }
  {
    owner: principal,
    price: uint,
    expiry: uint, ;; block height
    active: bool,
    listed-at: uint ;; block height
  }
)

;; Offers on NFTs
(define-map offers
  { contract-address: principal, token-id: uint, buyer: principal }
  {
    amount: uint,
    expiry: uint, ;; block height
    created-at: uint ;; block height
  }
)

;; Sales history
(define-map sales-history
  { contract-address: principal, token-id: uint, sale-id: uint }
  {
    seller: principal,
    buyer: principal,
    price: uint,
    royalty-amount: uint,
    marketplace-fee: uint,
    block-height: uint,
    tx-id: (buff 32)
  }
)

;; Sales counter per NFT
(define-map sales-counter
  { contract-address: principal, token-id: uint }
  { count: uint }
)

;; Contract management
(define-data-var contract-owner principal tx-sender)
(define-data-var marketplace-fee uint u25) ;; 2.5% marketplace fee
(define-data-var treasury principal tx-sender)
(define-data-var paused bool false)

;; Collection registry
(define-data-var collection-count uint u0)
(define-map registered-collections
  { index: uint }
  { contract-address: principal }
)