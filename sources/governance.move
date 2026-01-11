module fusd::governance {
    use std::signer;

    /// Error codes
    const E_NOT_ADMIN: u64 = 1;

    /// Global configuration
    struct FUSDConfig has key {
        target_price: u64,              // $1.00 in 8 decimals (100000000)
        expansion_factor: u64,
        contraction_factor: u64,
        last_rebalance_timestamp: u64,
        rebalancing_cooldown: u64,
        protocol_treasury: address,
        oracle_address: address,
        paused: bool,
    }

    /// Initialize governance with default parameters
    public entry fun initialize(admin: &signer, treasury: address, oracle: address) {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_ADMIN);

        move_to(admin, FUSDConfig {
            target_price: 100000000, // $1.00
            expansion_factor: 1000,   // 0.1 * 10000 bps? Spec says 0.1
            contraction_factor: 1500, // 0.15 * 10000 bps
            last_rebalance_timestamp: 0,
            rebalancing_cooldown: 21600, // 6 hours in seconds
            protocol_treasury: treasury,
            oracle_address: oracle,
            paused: false,
        });
    }

    public fun is_paused(): bool acquires FUSDConfig {
        borrow_global<FUSDConfig>(@fusd).paused
    }
    
    public fun get_config_values(): (u64, u64, u64, u64) acquires FUSDConfig {
        let config = borrow_global<FUSDConfig>(@fusd);
        (config.target_price, config.expansion_factor, config.contraction_factor, config.rebalancing_cooldown)
    }
}
