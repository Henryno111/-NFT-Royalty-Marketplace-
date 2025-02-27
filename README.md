# NFT Royalty Marketplace

A Clarity smart contract for the Stacks blockchain that implements a decentralized marketplace for NFTs with built-in royalty enforcement.

## Overview

The NFT Royalty Marketplace is a decentralized platform where users can list, buy, and sell NFTs with automatic royalty payments to original creators. The marketplace ensures that creators receive their fair share of secondary sales while providing a secure and efficient trading environment.

## Features

- **Collection Registration**: Register NFT collections with customizable royalty rates
- **Listing Management**: List, update, and cancel NFT listings
- **Secure Transactions**: Purchase NFTs with automatic distribution of funds
- **Royalty Enforcement**: Automatically enforce royalty payments to creators
- **Offer System**: Make and accept offers on any NFT
- **Sales History**: Track all sales with complete transaction details
- **Verification System**: Verified collections for improved trust
- **Marketplace Fee**: Sustainable business model with configurable marketplace fees

## Contract Architecture

The contract is divided into 4 logical components:

1. **Initial Setup (Data Structures)**: Core data structures and constants
2. **Helper Functions & Collection Management**: Utility functions and collection registration
3. **Listing Management & Purchase Functions**: NFT listing and buying functionality
4. **Offers, Admin Functions & Read Methods**: Offer system, administration, and read-only functions

## Key Data Structures

- `collections`: Stores NFT collection information including creator and royalty rates
- `listings`: Tracks active NFT listings with price and expiry
- `offers`: Manages offers made on NFTs
- `sales-history`: Records all completed transactions
- `sales-counter`: Tracks the number of sales per NFT

## Roles

- **Owner**: The contract deployer with administrative privileges
- **Collection Creators**: NFT collection creators who receive royalties
- **Sellers**: Users who list NFTs for sale
- **Buyers**: Users who purchase NFTs or make offers

## How to Use

### For Collection Creators

```clarity
;; Register your NFT collection
(contract-call? .nft-marketplace register-collection 
  'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.my-nfts 
  "My Amazing NFTs" 
  u50)  ;; 5% royalty
```

### For Sellers

```clarity
;; List your NFT for sale
(contract-call? .nft-marketplace list-nft 
  'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.my-nfts 
  u1  ;; token ID
  u1000000000  ;; price (1000 STX)
  (some u10000))  ;; expiry block height
```

### For Buyers

```clarity
;; Purchase an NFT
(contract-call? .nft-marketplace purchase-nft 
  'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.my-nfts 
  u1)  ;; token ID

;; Make an offer
(contract-call? .nft-marketplace make-offer
  'SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.my-nfts
  u1  ;; token ID
  u900000000  ;; offer amount (900 STX)
  none)  ;; default expiry
```

## Testing with Clarinet

1. Initialize a new project:
   ```
   clarinet new nft-marketplace && cd nft-marketplace
   ```

2. Add the contract to your project:
   ```
   clarinet contract new nft-marketplace
   ```

3. Copy the contract code into the generated file

4. Create test NFT contracts for testing:
   ```
   clarinet contract new test-nft
   ```

5. Run tests:
   ```
   clarinet test
   ```

## Security Considerations

- **Access Control**: Role-based permissions for administrative functions
- **Fee Limits**: Built-in limits on royalty rates and marketplace fees
- **Transaction Safety**: Secure transfer patterns with error handling
- **Expiry System**: All listings and offers have expiration dates
- **Pausable**: Emergency pause function for the entire marketplace

## Roadmap

- Multi-token sales (bundles)
- Auction system with timed bidding
- Cross-chain NFT support
- DAO governance for marketplace parameters
- Integration with external price oracles for non-STX payments

## License

MIT License

## Contact

For questions or contributions, please open an issue on the GitHub repository.

---

*This contract is provided as-is without any guarantees or warranty. Use at your own risk.*