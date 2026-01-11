module fusd::liquidity_pool {
    use std::signer;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;
    use fusd::fusd_coin::{Self, FUSD};

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 5001;
    const E_INSUFFICIENT_LIQUIDITY: u64 = 5002;
    const E_INVALID_AMOUNT: u64 = 5003;
    const E_ZERO_AMOUNT: u64 = 5004;

    /// Events
    struct ReserveDepositEvent has drop, store {
        amount: u64,
        timestamp: u64,
    }

    struct ReserveWithdrawEvent has drop, store {
        amount: u64,
        timestamp: u64,
    }

    /// Protocol Owned Liquidity State
    struct ProtocolLiquidity has key {
        total_liquidity_usd: u64,
        target_liquidity_ratio: u64,
        fusd_reserves: Coin<FUSD>,
        deposit_events: EventHandle<ReserveDepositEvent>,
        withdraw_events: EventHandle<ReserveWithdrawEvent>,
    }
    
    /// Insurance Fund State
    struct InsuranceFund has key {
        balance: Coin<FUSD>,
    }

    /// Initialize protocol liquidity management
    public entry fun initialize(admin: &signer) {
        if (!exists<ProtocolLiquidity>(signer::address_of(admin))) {
            move_to(admin, ProtocolLiquidity {
                total_liquidity_usd: 0,
                target_liquidity_ratio: 20,
                fusd_reserves: coin::zero<FUSD>(),
                deposit_events: account::new_event_handle<ReserveDepositEvent>(admin),
                withdraw_events: account::new_event_handle<ReserveWithdrawEvent>(admin),
            });
        };
        
        if (!exists<InsuranceFund>(signer::address_of(admin))) {
            move_to(admin, InsuranceFund {
                balance: coin::zero<FUSD>(),
            });
        }
    }

    /// Add FUSD to protocol reserves
    public entry fun add_to_reserves(admin: &signer, amount: u64) acquires ProtocolLiquidity {
        assert!(amount > 0, E_ZERO_AMOUNT);
        
        let admin_addr = signer::address_of(admin);
        let coins = coin::withdraw<FUSD>(admin, amount);
        
        let state = borrow_global_mut<ProtocolLiquidity>(@fusd);
        coin::merge(&mut state.fusd_reserves, coins);
        state.total_liquidity_usd = state.total_liquidity_usd + amount;
        
        // Emit event
        event::emit_event(&mut state.deposit_events, ReserveDepositEvent {
            amount,
            timestamp: aptos_framework::timestamp::now_seconds(),
        });
    }

    /// Remove FUSD from protocol reserves (Admin only)
    public entry fun remove_from_reserves(admin: &signer, amount: u64) acquires ProtocolLiquidity {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_AUTHORIZED);
        assert!(amount > 0, E_ZERO_AMOUNT);
        
        let state = borrow_global_mut<ProtocolLiquidity>(@fusd);
        let reserve_value = coin::value(&state.fusd_reserves);
        assert!(reserve_value >= amount, E_INSUFFICIENT_LIQUIDITY);
        
        let withdrawn = coin::extract(&mut state.fusd_reserves, amount);
        coin::deposit(admin_addr, withdrawn);
        
        state.total_liquidity_usd = if (state.total_liquidity_usd >= amount) {
            state.total_liquidity_usd - amount
        } else {
            0
        };
        
        // Emit event
        event::emit_event(&mut state.withdraw_events, ReserveWithdrawEvent {
            amount,
            timestamp: aptos_framework::timestamp::now_seconds(),
        });
    }

    /// Add to Insurance Fund
    public fun deposit_to_insurance_fund(coins: Coin<FUSD>) acquires InsuranceFund {
        let fund = borrow_global_mut<InsuranceFund>(@fusd);
        coin::merge(&mut fund.balance, coins);
    }
    
    /// Use Insurance Fund for contraction (called by rebalancing)
    public fun pull_from_insurance_fund(amount: u64): Coin<FUSD> acquires InsuranceFund {
        let fund = borrow_global_mut<InsuranceFund>(@fusd);
        let val = coin::value(&fund.balance);
        let pull_amount = if (val >= amount) { amount } else { val };
        coin::extract(&mut fund.balance, pull_amount)
    }

    /// Burn from reserves (called by rebalancing module)
    public fun burn_from_reserves(admin: &signer, amount: u64) acquires ProtocolLiquidity {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_AUTHORIZED);
        assert!(amount > 0, E_ZERO_AMOUNT);
        
        let state = borrow_global_mut<ProtocolLiquidity>(@fusd);
        let reserve_value = coin::value(&state.fusd_reserves);
        
        let burn_amount = if (reserve_value >= amount) {
            amount
        } else {
            reserve_value
        };
        
        if (burn_amount > 0) {
            let coins = coin::extract(&mut state.fusd_reserves, burn_amount);
            fusd_coin::burn_from_system(coins);
            
            state.total_liquidity_usd = if (state.total_liquidity_usd >= burn_amount) {
                state.total_liquidity_usd - burn_amount
            } else {
                0
            };
        }
    }

    /// Get total liquidity in USD
    public fun get_total_liquidity(): u64 acquires ProtocolLiquidity {
        if (exists<ProtocolLiquidity>(@fusd)) {
            borrow_global<ProtocolLiquidity>(@fusd).total_liquidity_usd
        } else {
            0
        }
    }

    /// Get FUSD reserve balance
    public fun get_fusd_reserves(): u64 acquires ProtocolLiquidity {
        if (exists<ProtocolLiquidity>(@fusd)) {
            coin::value(&borrow_global<ProtocolLiquidity>(@fusd).fusd_reserves)
        } else {
            0
        }
    }
    
    /// Get Insurance Fund balance
    public fun get_insurance_balance(): u64 acquires InsuranceFund {
        if (exists<InsuranceFund>(@fusd)) {
            coin::value(&borrow_global<InsuranceFund>(@fusd).balance)
        } else {
            0
        }
    }

    /// Update target liquidity ratio (Admin only)
    public entry fun set_target_ratio(admin: &signer, new_ratio: u64) acquires ProtocolLiquidity {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_AUTHORIZED);
        assert!(new_ratio > 0 && new_ratio <= 100, E_INVALID_AMOUNT);
        
        let state = borrow_global_mut<ProtocolLiquidity>(@fusd);
        state.target_liquidity_ratio = new_ratio;
    }
}
