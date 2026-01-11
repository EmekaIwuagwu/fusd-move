# FUSD Protocol Security Audit Report

**Audit Date**: January 11, 2026  
**Auditor**: Senior Blockchain Security Engineer  
**Protocol**: FUSD Algorithmic Stablecoin  
**Version**: 1.0.0  
**Network**: Aptos Testnet  

---

## Executive Summary

This audit examines the FUSD algorithmic stablecoin protocol deployed on Aptos blockchain. The protocol implements an elastic supply mechanism to maintain a $1.00 USD peg through automated rebalancing.

### Overall Risk Rating: **MEDIUM-HIGH** ⚠️

**Critical Findings**: 3  
**High Severity**: 4  
**Medium Severity**: 6  
**Low Severity**: 3  
**Informational**: 5  

---

## Critical Findings

### 🔴 CRITICAL-01: Centralized Admin Control
**Severity**: Critical  
**Module**: `fusd_coin.move`, `governance.move`  
**Lines**: 38-44, 74-108

**Issue**:
The protocol has a single admin address (`@fusd`) with unrestricted minting and burning capabilities. This creates a single point of failure and centralization risk.

```move
// fusd_coin.move:38
public fun mint(admin: &signer, amount: u64): Coin<FUSD> acquires FUSDManagement {
    let admin_addr = signer::address_of(admin);
    assert!(exists<FUSDManagement>(admin_addr), E_NOT_AUTHORIZED);
    // No additional checks - admin can mint unlimited FUSD
}
```

**Impact**:
- Admin can mint unlimited FUSD, destroying the peg
- Single compromised key = total protocol failure
- No multi-signature or timelock protection

**Recommendation**:
```move
// Implement multi-sig or DAO governance
struct AdminMultiSig has key {
    required_signatures: u64,
    signers: vector<address>,
    pending_operations: Table<u64, PendingOp>,
}

// Add minting caps
const MAX_MINT_PER_EPOCH: u64 = 1000000000; // 10 FUSD max
```

---

### 🔴 CRITICAL-02: Death Spiral Risk
**Severity**: Critical  
**Module**: `rebalancing.move`  
**Lines**: 75-107

**Issue**:
The contraction mechanism can fail if the admin doesn't have sufficient FUSD to burn, potentially creating a death spiral where the peg cannot be restored.

```move
// rebalancing.move:89-90
let balance = fusd_coin::balance(admin_addr);
let burn_amount = if (balance < amount_to_burn) { balance } else { amount_to_burn };
```

**Impact**:
- If admin balance is low, contraction is ineffective
- Price can spiral below peg without recovery mechanism
- Loss of user confidence → further selling → deeper depeg

**Recommendation**:
```move
// Pull from liquidity pool reserves
public fun burn_from_reserves(amount: u64) acquires ProtocolLiquidity {
    let reserves = borrow_global_mut<ProtocolLiquidity>(@fusd);
    let burn_coins = coin::extract(&mut reserves.fusd_reserves, amount);
    fusd_coin::burn_system(burn_coins);
}
```

---

### 🔴 CRITICAL-03: Oracle Manipulation Risk
**Severity**: Critical  
**Module**: `oracle_integration.move`  
**Lines**: 25-32

**Issue**:
Single admin-controlled oracle with no validation or external price source verification.

```move
// oracle_integration.move:25
public entry fun set_price(admin: &signer, new_price: u64) {
    // Admin can set ANY price with no validation
    oracle.price = new_price;
}
```

**Impact**:
- Admin can manipulate price to trigger favorable rebalancing
- No protection against flash loan attacks
- No TWAP (Time-Weighted Average Price) implementation

**Recommendation**:
```move
// Implement price bounds and TWAP
const MAX_PRICE_DEVIATION: u64 = 10000000; // 10% max change
const TWAP_WINDOW: u64 = 3600; // 1 hour

public entry fun set_price(admin: &signer, new_price: u64) {
    let old_price = oracle.price;
    assert!(
        new_price > old_price * 90 / 100 && new_price < old_price * 110 / 100,
        E_PRICE_DEVIATION_TOO_HIGH
    );
    // Update TWAP buffer
}
```

---

## High Severity Findings

### 🟠 HIGH-01: Integer Overflow in Reward Calculation
**Severity**: High  
**Module**: `rewards.move`  
**Lines**: 132-141

**Issue**:
Reward calculation uses u128 but doesn't check for overflow before casting back to u64.

```move
let base_reward = ((amount as u128) * (BASE_APY as u128) * (duration as u128)) / 
                 ((seconds_per_year as u128) * 10000);
return ((base_reward + bonus_reward) as u64); // Potential overflow
```

**Impact**:
- Large stakes or long durations could overflow
- Users receive incorrect (possibly zero) rewards
- Protocol insolvency if rewards are over-distributed

**Recommendation**:
```move
assert!(base_reward + bonus_reward <= (U64_MAX as u128), E_REWARD_OVERFLOW);
```

---

### 🟠 HIGH-02: Reentrancy in Unstake Function
**Severity**: High  
**Module**: `rewards.move`  
**Lines**: 85-115

**Issue**:
State is modified after external call to `coin::deposit()`.

```move
// rewards.move:110
coin::deposit(user_addr, payout); // External call
pool.total_distributed = pool.total_distributed + rewards; // State change AFTER
```

**Impact**:
- Potential reentrancy attack
- User could claim rewards multiple times
- Protocol fund drainage

**Recommendation**:
```move
// Update state BEFORE external calls
pool.total_distributed = pool.total_distributed + rewards;
stakes.total_staked = stakes.total_staked - amount;
coin::deposit(user_addr, payout); // External call last
```

---

### 🟠 HIGH-03: No Slippage Protection in Rebalancing
**Severity**: High  
**Module**: `rebalancing.move`  
**Lines**: 47-73

**Issue**:
Rebalancing executes at any price without slippage limits.

**Impact**:
- Large rebalances can move market price significantly
- MEV (Maximal Extractable Value) opportunities
- Unfavorable execution for protocol

**Recommendation**:
```move
const MAX_SLIPPAGE_BPS: u64 = 100; // 1% max slippage
// Check price before and after rebalancing
```

---

### 🟠 HIGH-04: Timestamp Manipulation
**Severity**: High  
**Module**: `governance.move`, `rewards.move`  
**Lines**: 59, 78

**Issue**:
Reliance on `timestamp::now_seconds()` which can be manipulated by validators.

**Impact**:
- Cooldown bypasses
- Reward calculation manipulation
- Lock period circumvention

**Recommendation**:
```move
// Use block height instead of timestamp for critical logic
const BLOCKS_PER_HOUR: u64 = 3600; // Assuming 1s blocks
```

---

## Medium Severity Findings

### 🟡 MEDIUM-01: Unbounded Vector Growth
**Severity**: Medium  
**Module**: `rewards.move`  
**Lines**: 76

**Issue**:
`UserStakes.positions` vector can grow unbounded.

```move
vector::push_back(&mut stakes.positions, StakingPosition { ... });
// No limit on number of positions
```

**Impact**:
- Gas costs increase linearly with positions
- Potential DoS if vector becomes too large
- User unable to interact with contract

**Recommendation**:
```move
const MAX_POSITIONS_PER_USER: u64 = 100;
assert!(vector::length(&stakes.positions) < MAX_POSITIONS_PER_USER, E_TOO_MANY_POSITIONS);
```

---

### 🟡 MEDIUM-02: Missing Input Validation
**Severity**: Medium  
**Module**: Multiple  

**Issue**:
Several functions lack input validation:
- `set_expansion_factor()` - no bounds checking
- `set_contraction_factor()` - no bounds checking  
- `stake()` - no minimum stake amount

**Recommendation**:
```move
const MIN_STAKE_AMOUNT: u64 = 100000000; // 1 FUSD
const MAX_EXPANSION_FACTOR: u64 = 5000; // 50% max
assert!(amount >= MIN_STAKE_AMOUNT, E_STAKE_TOO_SMALL);
assert!(new_factor <= MAX_EXPANSION_FACTOR, E_FACTOR_TOO_HIGH);
```

---

### 🟡 MEDIUM-03: Gas Abstraction Daily Limit Reset
**Severity**: Medium  
**Module**: `gas_abstraction.move`  
**Lines**: 52-56

**Issue**:
Daily limit resets based on time difference, not on a fixed daily boundary.

**Impact**:
- Users can game the system by timing transactions
- Inconsistent limit enforcement

**Recommendation**:
```move
// Reset at fixed UTC midnight
let current_day = current_time / SECONDS_PER_DAY;
let last_day = usage.last_reset_timestamp / SECONDS_PER_DAY;
if (current_day > last_day) { usage.daily_usage = 0; }
```

---

### 🟡 MEDIUM-04: No Emergency Withdrawal
**Severity**: Medium  
**Module**: `liquidity_pool.move`, `rewards.move`

**Issue**:
No emergency withdrawal mechanism if protocol is paused or compromised.

**Recommendation**:
```move
public entry fun emergency_withdraw(user: &signer) acquires UserStakes {
    assert!(governance::is_paused(), E_NOT_EMERGENCY);
    // Allow users to withdraw principal (no rewards) during emergency
}
```

---

### 🟡 MEDIUM-05: Precision Loss in Calculations
**Severity**: Medium  
**Module**: `rebalancing.move`  
**Lines**: 51-52, 79-80

**Issue**:
Integer division can cause precision loss in rebalancing calculations.

```move
let amount_u128 = val * (exp_factor as u128) / 10000 / (target_price as u128);
// Division order matters for precision
```

**Recommendation**:
```move
// Multiply first, divide last
let amount_u128 = (val * (exp_factor as u128)) / (10000 * (target_price as u128));
```

---

### 🟡 MEDIUM-06: No Rate Limiting on Rebalancing
**Severity**: Medium  
**Module**: `rebalancing.move`

**Issue**:
While there's a cooldown, there's no limit on frequency over longer periods.

**Recommendation**:
```move
const MAX_REBALANCES_PER_WEEK: u64 = 28; // ~4 per day max
struct RebalanceHistory has key {
    weekly_count: u64,
    week_start: u64,
}
```

---

## Low Severity Findings

### 🟢 LOW-01: Missing Events
**Severity**: Low  
**Modules**: `governance.move`, `liquidity_pool.move`

**Issue**:
Critical state changes don't emit events:
- `pause()` / `unpause()`
- `set_expansion_factor()`
- `add_to_reserves()`

**Recommendation**:
Add event emissions for all state changes.

---

### 🟢 LOW-02: Inconsistent Error Codes
**Severity**: Low  

**Issue**:
Error codes overlap across modules (e.g., `E_NOT_AUTHORIZED = 1` in multiple modules).

**Recommendation**:
Use module-specific error code ranges:
- `fusd_coin`: 1000-1099
- `governance`: 2000-2099
- etc.

---

### 🟢 LOW-03: No Version Control
**Severity**: Low  

**Issue**:
No version tracking in contracts for upgrades.

**Recommendation**:
```move
struct ProtocolVersion has key {
    major: u64,
    minor: u64,
    patch: u64,
}
```

---

## Informational Findings

### ℹ️ INFO-01: Gas Optimization
Several loops and calculations can be optimized for gas efficiency.

### ℹ️ INFO-02: Code Documentation
Add NatSpec-style documentation for all public functions.

### ℹ️ INFO-03: Test Coverage
Expand test coverage to include edge cases and attack scenarios.

### ℹ️ INFO-04: Upgrade Path
Define clear upgrade mechanism for future improvements.

### ℹ️ INFO-05: Monitoring
Implement on-chain monitoring for anomalous behavior.

---

## Recommendations Summary

### Immediate Actions (Before Mainnet)
1. ✅ Implement multi-signature for admin functions
2. ✅ Add oracle price validation and TWAP
3. ✅ Fix reentrancy in rewards module
4. ✅ Add bounds checking on all parameters
5. ✅ Implement emergency pause and withdrawal

### Short-term Improvements
1. Add comprehensive event emissions
2. Implement rate limiting on all user-facing functions
3. Add slippage protection to rebalancing
4. Expand test coverage to 100%
5. Conduct formal verification

### Long-term Enhancements
1. Transition to DAO governance
2. Integrate multiple oracle sources (Chainlink, Pyth, etc.)
3. Implement insurance fund
4. Add circuit breakers for extreme market conditions
5. Build monitoring and alerting infrastructure

---

## Conclusion

The FUSD protocol demonstrates solid Move programming practices and implements the core algorithmic stablecoin mechanics correctly. However, **critical centralization risks and lack of safety mechanisms make it unsuitable for mainnet deployment without significant improvements**.

### Risk Assessment

| Category | Risk Level | Status |
|----------|-----------|--------|
| Smart Contract Security | HIGH | ⚠️ Needs Work |
| Economic Model | MEDIUM-HIGH | ⚠️ Needs Testing |
| Centralization | CRITICAL | 🔴 Major Concern |
| Oracle Reliability | HIGH | ⚠️ Needs Improvement |
| User Fund Safety | MEDIUM | ⚠️ Add Protections |

### Deployment Recommendation

**❌ NOT RECOMMENDED for Mainnet** without addressing:
1. Critical findings (CRITICAL-01, CRITICAL-02, CRITICAL-03)
2. High severity findings (HIGH-01 through HIGH-04)
3. Multi-signature implementation
4. External audit by professional firm

**✅ ACCEPTABLE for Testnet** with:
- Clear disclaimers about experimental nature
- Limited user funds
- Active monitoring
- Rapid response capability

---

**Auditor Signature**: Senior Blockchain Security Engineer  
**Date**: January 11, 2026  
**Next Review**: After critical fixes implemented
