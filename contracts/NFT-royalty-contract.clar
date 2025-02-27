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
;; NFT Trait for interfacing with NFT contracts
(define-trait nft-trait
  (
    ;; Transfer from the sender to a new principal
    (transfer (uint principal principal) (response bool uint))
    ;; Get the owner of a token ID
    (get-owner (uint) (response (optional principal) uint))
    ;; Get the last token ID
    (get-last-token-id () (response uint uint))
    ;; Get the token URI
    (get-token-uri (uint) (response (optional (string-utf8 256)) uint))
  )
)

;; SIP-009 NFT trait for compatibility
(define-trait sip009-nft-trait
  (
    ;; Transfer from the sender to a new principal
    (transfer (uint principal principal) (response bool uint))
    ;; Get the owner of a token ID
    (get-owner (uint) (response (optional principal) uint))
    ;; Get the last token ID
    (get-last-token-id () (response uint uint))
    ;; Get the token URI
    (get-token-uri (uint) (response (optional (string-utf8 256)) uint))
  )
)

;; Event definitions
(define-trait marketplace-event-trait
  (
    (collection-registered (principal (string-ascii 64) principal uint) (response bool uint))
    (nft-listed (principal uint principal uint uint) (response bool uint))
    (nft-unlisted (principal uint principal) (response bool uint))
    (nft-sold (principal uint principal principal uint) (response bool uint))
    (offer-made (principal uint principal uint uint) (response bool uint))
    (offer-cancelled (principal uint principal) (response bool uint))
    (offer-accepted (principal uint principal principal uint) (response bool uint))
  )
)

;; Helper functions

;; Check if caller is contract owner
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Check if contract is paused
(define-private (is-paused)
  (var-get paused)
)

;; Check if a collection is registered
(define-private (is-registered (contract-address principal))
  (is-some (map-get? collections { contract-address: contract-address }))
)

;; Check if caller is the collection creator
(define-private (is-collection-creator (contract-address principal))
  (match (map-get? collections { contract-address: contract-address })
    collection (is-eq tx-sender (get creator collection))
    false
  )
)

;; Calculate marketplace fee
(define-private (calculate-marketplace-fee (price uint))
  (/ (* price (var-get marketplace-fee)) MARKETPLACE-FEE-DENOMINATOR)
)

;; Calculate royalty fee
(define-private (calculate-royalty-fee (contract-address principal) (price uint))
  (match (map-get? collections { contract-address: contract-address })
    collection (/ (* price (get royalty-rate collection)) MARKETPLACE-FEE-DENOMINATOR)
    u0
  )
)

;; Get sales count for an NFT
(define-private (get-sales-count (contract-address principal) (token-id uint))
  (default-to 
    u0
    (get count (map-get? sales-counter { contract-address: contract-address, token-id: token-id }))
  )
)

;; Increment sales count for an NFT
(define-private (increment-sales-count (contract-address principal) (token-id uint))
  (let ((current-count (get-sales-count contract-address token-id)))
    (map-set sales-counter
      { contract-address: contract-address, token-id: token-id }
      { count: (+ u1 current-count) }
    )
    (+ u1 current-count)
  )
)

;; Collection Management Functions

;; Register a new NFT collection
(define-public (register-collection (contract-address principal) (name (string-ascii 64)) (royalty-rate uint))
  (begin
    ;; Check if caller is the contract owner or if we're allowing public registration
    (asserts! (or (is-owner) true) ERR-NOT-AUTHORIZED)
    
    ;; Check if collection is already registered
    (asserts! (not (is-registered contract-address)) ERR-COLLECTION-ALREADY-REGISTERED)
    
    ;; Check if royalty rate is valid
    (asserts! (<= royalty-rate MAX-ROYALTY) ERR-INVALID-ROYALTY)
    
    ;; Register collection
    (map-set collections
      { contract-address: contract-address }
      {
        name: name,
        creator: tx-sender,
        royalty-rate: royalty-rate,
        verified: (is-owner),  ;; Only verify if registered by owner
        registered-by: tx-sender,
        registration-height: block-height
      }
    )
    
    ;; Add to registry
    (let ((current-count (var-get collection-count)))
      (map-set registered-collections
        { index: current-count }
        { contract-address: contract-address }
      )
      (var-set collection-count (+ u1 current-count))
    )
    
    ;; Print event
    (print { event: "collection-registered", contract: contract-address, name: name, creator: tx-sender, royalty: royalty-rate })
    (ok true)
  )
)

;; Verify a collection (only contract owner)
(define-public (verify-collection (contract-address principal))
  (begin
    ;; Check if caller is the contract owner
    (asserts! (is-owner) ERR-NOT-AUTHORIZED)
    
    ;; Check if collection is registered
    (asserts! (is-registered contract-address) ERR-COLLECTION-NOT-REGISTERED)
    
    ;; Update verification status
    (match (map-get? collections { contract-address: contract-address })
      collection
      (map-set collections
        { contract-address: contract-address }
        (merge collection { verified: true })
      )
      ERR-COLLECTION-NOT-REGISTERED
    )
    
    (ok true)
  )
)

;; Update collection royalty rate (only collection creator)
(define-public (update-royalty-rate (contract-address principal) (new-royalty-rate uint))
  (begin
    ;; Check if collection is registered
    (asserts! (is-registered contract-address) ERR-COLLECTION-NOT-REGISTERED)
    
    ;; Check if caller is collection creator
    (asserts! (is-collection-creator contract-address) ERR-NOT-AUTHORIZED)
    
    ;; Check if royalty rate is valid
    (asserts! (<= new-royalty-rate MAX-ROYALTY) ERR-INVALID-ROYALTY)
    
    ;; Update royalty rate
    (match (map-get? collections { contract-address: contract-address })
      collection
      (map-set collections
        { contract-address: contract-address }
        (merge collection { royalty-rate: new-royalty-rate })
      )
      ERR-COLLECTION-NOT-REGISTERED
    )
    
    (ok true)
  )
)
;; Listing Management Functions

;; List an NFT for sale
(define-public (list-nft (nft-contract <nft-trait>) (token-id uint) (price uint) (expiry (optional uint)))
  (let (
    (contract-address (contract-of nft-contract))
    (owner (unwrap! (contract-call? nft-contract get-owner token-id) ERR-NFT-TRANSFER-FAILED))
    (expire-at (default-to (+ block-height DEFAULT-EXPIRY) expiry))
  )
    ;; Check if contract is not paused
    (asserts! (not (is-paused)) ERR-LISTING-NOT-ACTIVE)
    
    ;; Check if caller is the owner of the NFT
    (asserts! (is-eq tx-sender (unwrap! owner ERR-NOT-OWNER)) ERR-NOT-OWNER)
    
    ;; Check if price is valid
    (asserts! (> price u0) ERR-INVALID-PRICE)
    
    ;; Check if expiry is valid
    (asserts! (> expire-at block-height) ERR-INVALID-EXPIRY)
    
    ;; Check if NFT is not already listed
    (asserts! (is-none (map-get? listings { contract-address: contract-address, token-id: token-id })) ERR-NFT-ALREADY-LISTED)
    
    ;; Create listing
    (map-set listings
      { contract-address: contract-address, token-id: token-id }
      {
        owner: tx-sender,
        price: price,
        expiry: expire-at,
        active: true,
        listed-at: block-height
      }
    )
    
    ;; Print event
    (print { event: "nft-listed", contract: contract-address, token-id: token-id, owner: tx-sender, price: price, expiry: expire-at })
    (ok true)
  )
)

;; Update an NFT listing
(define-public (update-listing (nft-contract <nft-trait>) (token-id uint) (new-price uint) (new-expiry (optional uint)))
  (let (
    (contract-address (contract-of nft-contract))
    (expire-at (default-to (+ block-height DEFAULT-EXPIRY) new-expiry))
  )
    ;; Check if contract is not paused
    (asserts! (not (is-paused)) ERR-LISTING-NOT-ACTIVE)
    
    ;; Check if NFT is listed
    (match (map-get? listings { contract-address: contract-address, token-id: token-id })
      listing
      (begin
        ;; Check if caller is the owner of the listing
        (asserts! (is-eq tx-sender (get owner listing)) ERR-NOT-OWNER)
        
        ;; Check if listing is active
        (asserts! (get active listing) ERR-LISTING-NOT-ACTIVE)
        
        ;; Check if listing has not expired
        (asserts! (<= block-height (get expiry listing)) ERR-LISTING-EXPIRED)
        
        ;; Check if price is valid
        (asserts! (> new-price u0) ERR-INVALID-PRICE)
        
        ;; Check if expiry is valid
        (asserts! (> expire-at block-height) ERR-INVALID-EXPIRY)
        
        ;; Update listing
        (map-set listings
          { contract-address: contract-address, token-id: token-id }
          (merge listing { 
            price: new-price,
            expiry: expire-at
          })
        )
        
        (ok true)
      )
      ERR-NFT-NOT-LISTED
    )
  )
)

;; Cancel an NFT listing
(define-public (cancel-listing (nft-contract <nft-trait>) (token-id uint))
  (let (
    (contract-address (contract-of nft-contract))
  )
    ;; Check if NFT is listed
    (match (map-get? listings { contract-address: contract-address, token-id: token-id })
      listing
      (begin
        ;; Check if caller is the owner of the listing
        (asserts! (is-eq tx-sender (get owner listing)) ERR-NOT-OWNER)
        
        ;; Delete listing
        (map-delete listings { contract-address: contract-address, token-id: token-id })
        
        ;; Print event
        (print { event: "nft-unlisted", contract: contract-address, token-id: token-id, owner: tx-sender })
        (ok true)
      )
      ERR-NFT-NOT-LISTED
    )
  )
)

;; Purchase an NFT
(define-public (purchase-nft (nft-contract <nft-trait>) (token-id uint))
  (let (
    (contract-address (contract-of nft-contract))
  )
    ;; Check if contract is not paused
    (asserts! (not (is-paused)) ERR-LISTING-NOT-ACTIVE)
    
    ;; Check if NFT is listed
    (match (map-get? listings { contract-address: contract-address, token-id: token-id })
      listing
      (let (
        (seller (get owner listing))
        (price (get price listing))
        (marketplace-fee-amount (calculate-marketplace-fee price))
        (royalty-amount (calculate-royalty-fee contract-address price))
        (seller-amount (- price (+ marketplace-fee-amount royalty-amount)))
      )
        ;; Check if listing is active
        (asserts! (get active listing) ERR-LISTING-NOT-ACTIVE)
        
        ;; Check if listing has not expired
        (asserts! (<= block-height (get expiry listing)) ERR-LISTING-EXPIRED)
        
        ;; Check if buyer is not the seller
        (asserts! (not (is-eq tx-sender seller)) ERR-SAME-OWNER)
        
        ;; Transfer STX from buyer to marketplace, creator, and seller
        
        ;; Transfer marketplace fee
        (unwrap! (stx-transfer? marketplace-fee-amount tx-sender (var-get treasury)) ERR-STX-TRANSFER-FAILED)
        
        ;; Transfer royalty fee to creator if collection is registered
        (if (is-registered contract-address)
          (let ((collection (unwrap! (map-get? collections { contract-address: contract-address }) ERR-COLLECTION-NOT-REGISTERED)))
            (unwrap! (stx-transfer? royalty-amount tx-sender (get creator collection)) ERR-STX-TRANSFER-FAILED)
          )
          true
        )
        
        ;; Transfer remaining amount to seller
        (unwrap! (stx-transfer? seller-amount tx-sender seller) ERR-STX-TRANSFER-FAILED)
        
        ;; Transfer NFT from seller to buyer
        (unwrap! (contract-call? nft-contract transfer token-id seller tx-sender) ERR-NFT-TRANSFER-FAILED)
        
        ;; Record sale in history
        (let ((sale-id (increment-sales-count contract-address token-id)))
          (map-set sales-history
            { contract-address: contract-address, token-id: token-id, sale-id: sale-id }
            {
              seller: seller,
              buyer: tx-sender,
              price: price,
              royalty-amount: royalty-amount,
              marketplace-fee: marketplace-fee-amount,
              block-height: block-height,
              tx-id: tx-hash
            }
          )
        )
        
        ;; Remove listing
        (map-delete listings { contract-address: contract-address, token-id: token-id })
        
        ;; Print event
        (print { event: "nft-sold", contract: contract-address, token-id: token-id, seller: seller, buyer: tx-sender, price: price })
        (ok true)
      )
      ERR-NFT-NOT-LISTED
    )
  )
)