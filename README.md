# FUSD Stablecoin Protocol

FUSD is an advanced algorithmic stablecoin built on the Aptos blockchain, featuring dynamic supply rebalancing, protocol-owned liquidity, and gas fee abstraction.

## Features

### 1. Algorithmic Stability
- **Expansion**: When price > $1.00, new FUSD is minted to treasury and holders.
- **Contraction**: When price < $1.00, FUSD is burned from the treasury/pools to restore peg.
- **Oracle Integration**: Uses robust price feeds (Mock/Pyth) with staleness checks.

### 2. Protocol-Owned Liquidity (POL)
- The protocol manages its own liquidity across DEXes.
- Supports FUSD/APT, FUSD/USDC pairs.
- Automated management of LP tokens.

### 3. Gas Abstraction
- Users can pay transaction fees in FUSD.
- The protocol acts as the Fee Payer (paying APT) and deducts FUSD from the user.

## Project Structure

- `sources/`: Move smart contract modules.
- `tests/`: Unit and integration tests.
- `scripts/`: Deployment and initialization scripts.

## Setup & Testing

### Prerequisites
- [Aptos CLI](https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli) (v7.13.0+)

### Running Tests
```bash
aptos move test --package-dir . --named-addresses fusd=0x1
```

### Local Deployment
```bash
# Start local node
aptos node run-local-testnet --with-faucet

# Deploy
./scripts/deploy_local.sh
```

## Security
- **Access Control**: Critical functions are restricted to Admin/Governance.
- **Rate Limiting**: Gas abstraction and Rebalancing have cooldowns/caps.
- **Verification**: Formally verified modules (Prover specs pending).

## License
MIT
