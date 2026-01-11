module fusd::governance {
    use std::signer;
    use aptos_framework::timestamp;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;

    /// Error codes
    const E_NOT_ADMIN: u64 = 2001;
    const E_PAUSED: u64 = 2002;
    const E_COOLDOWN_ACTIVE: u64 = 2003;
    const E_INVALID_FACTOR: u64 = 2004;
    const E_INVALID_COOLDOWN: u64 = 2005;

    /// Maximum factor values (50% max)
    const MAX_EXPANSION_FACTOR: u64 = 5000;
    const MAX_CONTRACTION_FACTOR: u64 = 5000;
    const MIN_COOLDOWN: u64 = 3600; // 1 hour minimum
    const MAX_COOLDOWN: u64 = 86400; // 24 hours maximum

    /// Events
    struct PauseEvent has drop, store {
        paused: bool,
        timestamp: u64,
    }

    struct FactorUpdateEvent has drop, store {
        factor_type: u8, // 1 = expansion, 2 = contraction
        old_value: u64,
        new_value: u64,
        timestamp: u64,
    }

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
        pause_events: EventHandle<PauseEvent>,
        factor_events: EventHandle<FactorUpdateEvent>,
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
            pause_events: account::new_event_handle<PauseEvent>(admin),
            factor_events: account::new_event_handle<FactorUpdateEvent>(admin),
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
        
        // Emit event
        event::emit_event(&mut config.pause_events, PauseEvent {
            paused: true,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// Unpause protocol (Admin only)
    public entry fun unpause(admin: &signer) acquires FUSDConfig {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_ADMIN);
        
        let config = borrow_global_mut<FUSDConfig>(@fusd);
        config.paused = false;
        
        // Emit event
        event::emit_event(&mut config.pause_events, PauseEvent {
            paused: false,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// Update expansion factor with validation (Admin only)
    public entry fun set_expansion_factor(admin: &signer, new_factor: u64) acquires FUSDConfig {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_ADMIN);
        assert!(new_factor > 0 && new_factor <= MAX_EXPANSION_FACTOR, E_INVALID_FACTOR);
        
        let config = borrow_global_mut<FUSDConfig>(@fusd);
        let old_factor = config.expansion_factor;
        config.expansion_factor = new_factor;
        
        // Emit event
        event::emit_event(&mut config.factor_events, FactorUpdateEvent {
            factor_type: 1,
            old_value: old_factor,
            new_value: new_factor,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// Update contraction factor with validation (Admin only)
    public entry fun set_contraction_factor(admin: &signer, new_factor: u64) acquires FUSDConfig {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_ADMIN);
        assert!(new_factor > 0 && new_factor <= MAX_CONTRACTION_FACTOR, E_INVALID_FACTOR);
        
        let config = borrow_global_mut<FUSDConfig>(@fusd);
        let old_factor = config.contraction_factor;
        config.contraction_factor = new_factor;
        
        // Emit event
        event::emit_event(&mut config.factor_events, FactorUpdateEvent {
            factor_type: 2,
            old_value: old_factor,
            new_value: new_factor,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// Update cooldown period with validation (Admin only)
    public entry fun set_cooldown(admin: &signer, new_cooldown: u64) acquires FUSDConfig {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_ADMIN);
        assert!(
            new_cooldown >= MIN_COOLDOWN && new_cooldown <= MAX_COOLDOWN,
            E_INVALID_COOLDOWN
        );
        
        let config = borrow_global_mut<FUSDConfig>(@fusd);
        config.rebalancing_cooldown = new_cooldown;
    }

    /// Get time until next rebalance is allowed
    public fun time_until_next_rebalance(): u64 acquires FUSDConfig {
        let config = borrow_global<FUSDConfig>(@fusd);
        let current_time = timestamp::now_seconds();
        
        if (config.last_rebalance_timestamp == 0) {
            return 0
        };
        
        let elapsed = current_time - config.last_rebalance_timestamp;
        if (elapsed >= config.rebalancing_cooldown) {
            0
        } else {
            config.rebalancing_cooldown - elapsed
        }
    }
}
