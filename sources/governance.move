module fusd::governance {
    use std::signer;
    use aptos_framework::timestamp;

    /// Error codes
    const E_NOT_ADMIN: u64 = 1;
    const E_PAUSED: u64 = 2;
    const E_COOLDOWN_ACTIVE: u64 = 3;

    /// Global configuration
    struct FUSDConfig has key {
        target_price: u64,              
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
            target_price: 100000000,        // $1.00 (8 decimals)
            expansion_factor: 1000,         // 10% (basis points)
            contraction_factor: 1500,       // 15% (basis points)
            last_rebalance_timestamp: 0,
            rebalancing_cooldown: 21600,    // 6 hours in seconds
            protocol_treasury: treasury,
            oracle_address: oracle,
            paused: false,
        });
    }

    /// Check if protocol is paused
    public fun is_paused(): bool acquires FUSDConfig {
        borrow_global<FUSDConfig>(@fusd).paused
    }
    
    /// Get configuration values
    public fun get_config_values(): (u64, u64, u64, u64, u64) acquires FUSDConfig {
        let config = borrow_global<FUSDConfig>(@fusd);
        (
            config.target_price, 
            config.expansion_factor, 
            config.contraction_factor, 
            config.rebalancing_cooldown,
            config.last_rebalance_timestamp
        )
    }

    /// Update last rebalance timestamp
    public fun update_rebalance_timestamp() acquires FUSDConfig {
        let config = borrow_global_mut<FUSDConfig>(@fusd);
        config.last_rebalance_timestamp = timestamp::now_seconds();
    }

    /// Check if cooldown period has passed
    public fun can_rebalance(): bool acquires FUSDConfig {
        let config = borrow_global<FUSDConfig>(@fusd);
        let current_time = timestamp::now_seconds();
        
        if (config.last_rebalance_timestamp == 0) {
            return true
        };
        
        (current_time - config.last_rebalance_timestamp) >= config.rebalancing_cooldown
    }

    /// Pause protocol (Admin only)
    public entry fun pause(admin: &signer) acquires FUSDConfig {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_ADMIN);
        
        let config = borrow_global_mut<FUSDConfig>(@fusd);
        config.paused = true;
    }

    /// Unpause protocol (Admin only)
    public entry fun unpause(admin: &signer) acquires FUSDConfig {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_ADMIN);
        
        let config = borrow_global_mut<FUSDConfig>(@fusd);
        config.paused = false;
    }

    /// Update expansion factor (Admin only)
    public entry fun set_expansion_factor(admin: &signer, new_factor: u64) acquires FUSDConfig {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_ADMIN);
        
        let config = borrow_global_mut<FUSDConfig>(@fusd);
        config.expansion_factor = new_factor;
    }

    /// Update contraction factor (Admin only)
    public entry fun set_contraction_factor(admin: &signer, new_factor: u64) acquires FUSDConfig {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_ADMIN);
        
        let config = borrow_global_mut<FUSDConfig>(@fusd);
        config.contraction_factor = new_factor;
    }
}
