# FUSD Stablecoin Protocol

![Aptos](https://img.shields.io/badge/Aptos-Testnet-blue)
![Move](https://img.shields.io/badge/Move-Language-green)
![License](https://img.shields.io/badge/License-MIT-yellow)
![Security](https://img.shields.io/badge/Security-Hardened-green)
![Status](https://img.shields.io/badge/Status-v1.1.0-blue)

> ✅ **SECURITY UPDATE v1.1.0**: All critical vulnerabilities fixed! See [SECURITY_FIXES.md](SECURITY_FIXES.md) for details. Original audit: [SECURITY_AUDIT.md](SECURITY_AUDIT.md). **Testnet ready** - Mainnet requires multi-sig governance.

FUSD is a production-ready algorithmic stablecoin built on the Aptos blockchain, featuring dynamic supply rebalancing, protocol-owned liquidity, gas fee abstraction, and LP staking rewards.

## 🌟 Features

### 1. Algorithmic Stability
- **Dynamic Rebalancing**: Automatic supply adjustments to maintain $1.00 peg
- **Expansion**: When price > $1.005, new FUSD is minted (10% of deviation)
- **Contraction**: When price < $0.995, FUSD is burned (15% of deviation)
- **Oracle Integration**: Real-time price feeds with staleness protection (60s max)
- **Safety Caps**: Maximum 5% supply change per rebalancing event
- **Cooldown Period**: 6-hour minimum between rebalancing operations

### 2. Protocol-Owned Liquidity (POL)
- Autonomous liquidity management across DEXes
- FUSD reserve pool for protocol operations
- Configurable target liquidity ratios
- Admin-controlled reserve deposits and withdrawals

### 3. LP Staking & Rewards
- **Lock Periods**: 30, 90, or 365 days
- **Base APY**: 15% for all stakers
- **Bonus Rewards**: 
  - 30 days: +5% (20% total APY)
  - 90 days: +15% (30% total APY)
  - 365 days: +30% (45% total APY)
- Automatic reward calculation based on stake duration
- Flexible unstaking after lock period expires

### 4. Gas Fee Abstraction
- Pay transaction fees in FUSD instead of APT
- 2% convenience fee on gas payments
- Daily usage caps: 100 FUSD per user
- Automatic daily limit reset
- Real-time APT/USD price conversion

### 5. Governance & Security
- Pause/unpause protocol functionality
- Configurable expansion and contraction factors
- Admin-only critical functions
- Timestamp-based cooldown enforcement
- Multi-layer access control

## 📦 Project Structure

```
fusd-move/
├── sources/
│   ├── fusd_coin.move           # Core FUSD token (mint/burn/transfer)
│   ├── governance.move          # Protocol configuration & admin controls
│   ├── oracle_integration.move  # Price oracle with staleness checks
│   ├── rebalancing.move         # Algorithmic stability mechanism
│   ├── liquidity_pool.move      # Protocol-owned liquidity management
│   ├── rewards.move             # LP staking and reward distribution
│   ├── gas_abstraction.move     # FUSD-based gas fee payment
│   └── events.move              # Event definitions
├── tests/
│   ├── fusd_coin_tests.move
│   ├── rebalancing_tests.move
│   └── integration_tests.move
└── scripts/
    ├── deploy_local.sh
    └── deploy_testnet.sh
```

## 🚀 Deployment

### Testnet Deployment (Live) - v1.1.0 ✅
- **Network**: Aptos Testnet
- **Version**: 1.1.0 (Security Hardened)
- **Contract Address**: `0x2791c639877af206489abee02270c597aa6aea0e3c896b72cc99bb4832ca37e7`
- **Deployment Date**: January 11, 2026
- **Status**: Live and Operational

#### 🔗 Explorer Links
- **Account Overview**: [View Account](https://explorer.aptoslabs.com/account/0x2791c639877af206489abee02270c597aa6aea0e3c896b72cc99bb4832ca37e7?network=testnet)
- **Deployed Modules**: [View Modules](https://explorer.aptoslabs.com/account/0x2791c639877af206489abee02270c597aa6aea0e3c896b72cc99bb4832ca37e7/modules?network=testnet)
- **Transactions**: [View Transactions](https://explorer.aptoslabs.com/account/0x2791c639877af206489abee02270c597aa6aea0e3c896b72cc99bb4832ca37e7/transactions?network=testnet)

#### 📊 Deployment Transactions
| Module | Transaction | Status |
|--------|-------------|--------|
| Contract Publish | [0xb899c5...7b43](https://explorer.aptoslabs.com/txn/0xb899c5d3c1b941e4831ebc290e149df32962b575f46b74a6b495596bb2bf7b43?network=testnet) | ✅ Success |
| FUSD Coin Init | [0x164a71...8efd](https://explorer.aptoslabs.com/txn/0x164a719bcdd345578eb58595b8acb4528f4abbc988b6216f03d4d4af6cf58efd?network=testnet) | ✅ Success |
| Governance Init | [0xcb325b...5668](https://explorer.aptoslabs.com/txn/0xcb325b5d09239346b13ba56e170dbe42bd9f03f3bc9380cbf8f3909880fd5668?network=testnet) | ✅ Success |
| Oracle Init | [0x994cea...0a34](https://explorer.aptoslabs.com/txn/0x994ceafa691107c3cbebd331f5f0f9e982e41c2c1e0bd5f7cfd1762815750a34?network=testnet) | ✅ Success |
| Rebalancing Init | [0x7cde92...ca05](https://explorer.aptoslabs.com/txn/0x7cde925dc02cb4b55a960b6a576b24cc9ca5143cbcd5e8f018a825f85b4eca05?network=testnet) | ✅ Success |
| Liquidity Pool Init | [0x6b0815...1d45](https://explorer.aptoslabs.com/txn/0x6b08154f61e3d47dba10fcb88c5d270975bf7ac2cbc172969112cc1f7a821d45?network=testnet) | ✅ Success |
| Gas Abstraction Init | [0x83b258...f560](https://explorer.aptoslabs.com/txn/0x83b258d5432a91f803b8d7c65c136ed41db7ec0afa9c1aaa9a72ec931c8cf560?network=testnet) | ✅ Success |

**Total Deployment Cost**: 0.0187 APT (~$0.19 USD)

See [TESTNET_DEPLOYMENT.md](TESTNET_DEPLOYMENT.md) for complete deployment details.

## 🛠️ Setup & Testing

### Prerequisites
- [Aptos CLI](https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli) v7.13.0+
- Git

### Installation
```bash
git clone https://github.com/EmekaIwuagwu/fusd-move.git
cd fusd-move
```

### Running Tests
```bash
aptos move test --named-addresses fusd=0x1
```

### Local Deployment
```bash
# Start local testnet
aptos node run-local-testnet --with-faucet

# Deploy contracts
./scripts/deploy_local.sh
```

### Testnet Deployment
```bash
# Initialize profile
aptos init --profile fusd-testnet --network testnet

# Fund account from faucet
# Visit: https://aptos.dev/network/faucet

# Deploy
./scripts/deploy_testnet.sh
```

## 📖 Usage Examples

### Token Information
- **Name**: FUSD Stablecoin
- **Symbol**: FUSD
- **Decimals**: 8
- **Target Peg**: $1.00 USD
- **Supply Model**: Elastic (algorithmic expansion/contraction)
- **Contract**: `0x2791c639877af206489abee02270c597aa6aea0e3c896b72cc99bb4832ca37e7`

### Register for FUSD
```bash
aptos move run \
  --function-id '0x2791c639877af206489abee02270c597aa6aea0e3c896b72cc99bb4832ca37e7::fusd_coin::register' \
  --profile your-profile \
  --network testnet
```

### Stake FUSD (90-day lock for 30% APY)
```bash
aptos move run \
  --function-id '0x2791c639877af206489abee02270c597aa6aea0e3c896b72cc99bb4832ca37e7::rewards::stake' \
  --args u64:100000000 u64:7776000 \
  --profile your-profile \
  --network testnet
```

### Check Your Staking Balance
```bash
aptos move view \
  --function-id '0x2791c639877af206489abee02270c597aa6aea0e3c896b72cc99bb4832ca37e7::rewards::get_total_staked' \
  --args address:YOUR_ADDRESS \
  --network testnet
```

### View Current FUSD Supply
```bash
aptos move view \
  --function-id '0x2791c639877af206489abee02270c597aa6aea0e3c896b72cc99bb4832ca37e7::fusd_coin::get_supply' \
  --network testnet
```

### Check Oracle Price
```bash
aptos move view \
  --function-id '0x2791c639877af206489abee02270c597aa6aea0e3c896b72cc99bb4832ca37e7::oracle_integration::get_price' \
  --network testnet
```

## 🔒 Security Features

- **Access Control**: Critical functions restricted to protocol admin
- **Rate Limiting**: Gas abstraction has daily caps per user
- **Cooldown Enforcement**: Minimum 6 hours between rebalancing events
- **Price Staleness**: Oracle prices rejected if older than 60 seconds
- **Supply Caps**: Maximum 5% supply change per rebalancing
- **Pause Mechanism**: Emergency protocol pause functionality
- **Input Validation**: All user inputs validated for correctness

## 📊 Economic Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Target Price | $1.00 | Stable peg target |
| Price Threshold | ±0.5% | Rebalancing trigger |
| Expansion Factor | 10% | Mint amount on expansion |
| Contraction Factor | 15% | Burn amount on contraction |
| Max Rebalance | 5% | Maximum supply change |
| Cooldown Period | 6 hours | Minimum between rebalances |
| Base Staking APY | 15% | Reward for all stakers |
| Gas Convenience Fee | 2% | Fee for FUSD gas payments |

## 🧪 Testing Coverage

- ✅ Core coin operations (mint, burn, transfer)
- ✅ Oracle price updates and staleness checks
- ✅ Rebalancing expansion and contraction
- ✅ Cooldown period enforcement
- ✅ Staking and unstaking flows
- ✅ Gas abstraction with rate limiting
- ✅ Integration tests for full lifecycle

## 🔒 Security Audit & Fixes

### ✅ Version 1.1.0 - Security Hardened

All critical vulnerabilities have been fixed! See [SECURITY_FIXES.md](SECURITY_FIXES.md) for complete implementation details.

### Fixes Summary
- ✅ **3 Critical** vulnerabilities FIXED (100%)
- ✅ **4 High Severity** issues FIXED (100%)
- ✅ **6 Medium Severity** concerns FIXED (100%)
- ✅ **3 Low Severity** items FIXED (100%)

### Key Improvements
1. ✅ Epoch-based mint limits (prevents unlimited minting)
2. ✅ Multi-source burning (prevents death spiral)
3. ✅ TWAP + price deviation limits (prevents oracle manipulation)
4. ✅ Reentrancy protection (state-before-call pattern)
5. ✅ Overflow protection (all calculations checked)
6. ✅ Comprehensive input validation
7. ✅ Full event coverage for monitoring

### Deployment Status
- ✅ **Testnet**: Ready for expanded testing
- ⚠️ **Mainnet**: Requires multi-signature governance + professional audit

### Original Audit
For the original security audit that identified these issues, see [SECURITY_AUDIT.md](SECURITY_AUDIT.md).

## 📝 License

This project is licensed under the MIT License.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📧 Contact

For questions or support, please open an issue on GitHub.


---

**Version**: 1.1.0 (Security Hardened)  
**Status**: Production-ready for testnet deployment  
**License**: MIT (see LICENSE for full terms and risk disclosures)  
**Security**: Self-audited with all critical vulnerabilities fixed. Professional third-party audit recommended before mainnet.
