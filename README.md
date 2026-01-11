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

### Testnet Deployment (Live)
- **Network**: Aptos Testnet
- **Contract Address**: `0xb1899c39c9b05fd6b25b7b8329a355f06186d80d414578ec752135ade379a5a7`
- **Explorer**: [View on Aptos Explorer](https://explorer.aptoslabs.com/account/0xb1899c39c9b05fd6b25b7b8329a355f06186d80d414578ec752135ade379a5a7?network=testnet)

### Token Information
- **Name**: FUSD Stablecoin
- **Symbol**: FUSD
- **Decimals**: 8
- **Target Peg**: $1.00 USD
- **Supply Model**: Elastic (algorithmic expansion/contraction)

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

### Register for FUSD
```bash
aptos move run \
  --function-id '0xb1899c39c9b05fd6b25b7b8329a355f06186d80d414578ec752135ade379a5a7::fusd_coin::register' \
  --profile your-profile
```

### Stake FUSD (90-day lock)
```bash
aptos move run \
  --function-id '0xb1899c39c9b05fd6b25b7b8329a355f06186d80d414578ec752135ade379a5a7::rewards::stake' \
  --args u64:100000000 u64:7776000 \
  --profile your-profile
```

### Check Staking Balance
```bash
aptos move view \
  --function-id '0xb1899c39c9b05fd6b25b7b8329a355f06186d80d414578ec752135ade379a5a7::rewards::get_total_staked' \
  --args address:YOUR_ADDRESS
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
