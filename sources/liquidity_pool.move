module fusd::liquidity_pool {
    use std::signer;
    use aptos_framework::coin::{Self, Coin};
    use fusd::fusd_coin::FUSD;

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_INSUFFICIENT_LIQUIDITY: u64 = 2;
    const E_INVALID_AMOUNT: u64 = 3;

    /// Protocol Owned Liquidity State
    struct ProtocolLiquidity has key {
        total_liquidity_usd: u64,
        target_liquidity_ratio: u64,
        fusd_reserves: Coin<FUSD>,
    }

    /// Initialize protocol liquidity management
    public entry fun initialize(admin: &signer) {
        if (!exists<ProtocolLiquidity>(signer::address_of(admin))) {
            move_to(admin, ProtocolLiquidity {
                total_liquidity_usd: 0,
                target_liquidity_ratio: 20,
                fusd_reserves: coin::zero<FUSD>(),
            });
        }
    }

    /// Add FUSD to protocol reserves
    public entry fun add_to_reserves(admin: &signer, amount: u64) acquires ProtocolLiquidity {
        assert!(amount > 0, E_INVALID_AMOUNT);
        
        let admin_addr = signer::address_of(admin);
        let coins = coin::withdraw<FUSD>(admin, amount);
        
        let state = borrow_global_mut<ProtocolLiquidity>(admin_addr);
        coin::merge(&mut state.fusd_reserves, coins);
        state.total_liquidity_usd = state.total_liquidity_usd + amount;
    }

    /// Remove FUSD from protocol reserves
    public entry fun remove_from_reserves(admin: &signer, amount: u64) acquires ProtocolLiquidity {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_AUTHORIZED);
        
        let state = borrow_global_mut<ProtocolLiquidity>(admin_addr);
        let reserve_value = coin::value(&state.fusd_reserves);
        assert!(reserve_value >= amount, E_INSUFFICIENT_LIQUIDITY);
        
        let withdrawn = coin::extract(&mut state.fusd_reserves, amount);
        coin::deposit(admin_addr, withdrawn);
        
        state.total_liquidity_usd = if (state.total_liquidity_usd >= amount) {
            state.total_liquidity_usd - amount
        } else {
            0
        };
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

    /// Update target liquidity ratio (Admin only)
    public entry fun set_target_ratio(admin: &signer, new_ratio: u64) acquires ProtocolLiquidity {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_AUTHORIZED);
        
        let state = borrow_global_mut<ProtocolLiquidity>(admin_addr);
        state.target_liquidity_ratio = new_ratio;
    }
}
