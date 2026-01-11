module fusd::governance {
    use std::signer;
    use std::option;
    use aptos_framework::timestamp;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;

    /// Error codes
    const E_NOT_ADMIN: u64 = 2001;
    const E_PAUSED: u64 = 2002;
    const E_COOLDOWN_ACTIVE: u64 = 2003;
    const E_INVALID_FACTOR: u64 = 2004;
    const E_INVALID_COOLDOWN: u64 = 2005;
    const E_NO_PENDING_ACTION: u64 = 2006;
    const E_TIMELOCK_ACTIVE: u64 = 2007;
    const E_CIRCUIT_BREAKER_TRIGGERED: u64 = 2008;
    const E_DEPRECATED: u64 = 2009;

    /// Maximum factor values (50% max)
    const MAX_EXPANSION_FACTOR: u64 = 5000;
    const MAX_CONTRACTION_FACTOR: u64 = 5000;
    const MIN_COOLDOWN: u64 = 3600; // 1 hour minimum
    const MAX_COOLDOWN: u64 = 86400; // 24 hours maximum
    
    /// Timelock duration (24 hours)
    const TIMELOCK_DURATION: u64 = 86400;
    
    /// Circuit Breaker Threshold (25% deviation from peg)
    const CIRCUIT_BREAKER_THRESHOLD_BPS: u64 = 2500;

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
    
    struct PendingAction has drop, store {
        action_type: u8, // 1 = set_expansion, 2 = set_contraction, 3 = set_cooldown
        value: u64,
        execution_time: u64,
    }

    /// Global configuration.
    /// Note: This struct must maintain its original layout for backward compatibility.
    /// New fields are in GovernanceState.
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

    /// New state struct to hold additional fields without breaking FUSDConfig layout
    struct GovernanceState has key {
        circuit_breaker_triggered: bool,
        pending_action: option::Option<PendingAction>,
    }

    /// Initialize governance with default parameters
    public entry fun initialize(admin: &signer, treasury: address, oracle: address) {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_ADMIN);

        if (!exists<FUSDConfig>(admin_addr)) {
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
        };

        if (!exists<GovernanceState>(admin_addr)) {
            move_to(admin, GovernanceState {
                circuit_breaker_triggered: false,
                pending_action: std::option::none<PendingAction>(),
            });
        }
    }

    /// Upgrade contract to add GovernanceState if missing (Migration helper)
    public entry fun upgrade_contract(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_ADMIN);
        
        if (!exists<GovernanceState>(admin_addr)) {
            move_to(admin, GovernanceState {
                circuit_breaker_triggered: false,
                pending_action: std::option::none<PendingAction>(),
            });
        }
    }

    /// Check if protocol is paused
    public fun is_paused(): bool acquires FUSDConfig, GovernanceState {
        let config = borrow_global<FUSDConfig>(@fusd);
        let circuit_triggered = if (exists<GovernanceState>(@fusd)) {
            borrow_global<GovernanceState>(@fusd).circuit_breaker_triggered
        } else {
            false
        };
        config.paused || circuit_triggered
    }

    /// Check if circuit breaker is triggered
    public fun is_circuit_breaker_triggered(): bool acquires GovernanceState {
        if (exists<GovernanceState>(@fusd)) {
            borrow_global<GovernanceState>(@fusd).circuit_breaker_triggered
        } else {
            false
        }
    }
    
    /// Trigger circuit breaker
    public fun trigger_circuit_breaker() acquires GovernanceState {
        if (exists<GovernanceState>(@fusd)) {
            let state = borrow_global_mut<GovernanceState>(@fusd);
            state.circuit_breaker_triggered = true;
        }
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
    public entry fun unpause(admin: &signer) acquires FUSDConfig, GovernanceState {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_ADMIN);
        
        let config = borrow_global_mut<FUSDConfig>(@fusd);
        config.paused = false;

        if (exists<GovernanceState>(@fusd)) {
            let state = borrow_global_mut<GovernanceState>(@fusd);
            state.circuit_breaker_triggered = false;
        };
        
        // Emit event
        event::emit_event(&mut config.pause_events, PauseEvent {
            paused: false,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// Propose expansion factor update (Admin only)
    public entry fun propose_expansion_factor(admin: &signer, new_factor: u64) acquires GovernanceState {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_ADMIN);
        assert!(new_factor > 0 && new_factor <= MAX_EXPANSION_FACTOR, E_INVALID_FACTOR);
        
        let state = borrow_global_mut<GovernanceState>(@fusd);
        state.pending_action = std::option::some(PendingAction {
            action_type: 1,
            value: new_factor,
            execution_time: timestamp::now_seconds() + TIMELOCK_DURATION,
        });
    }

    /// Propose contraction factor update (Admin only)
    public entry fun propose_contraction_factor(admin: &signer, new_factor: u64) acquires GovernanceState {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_ADMIN);
        assert!(new_factor > 0 && new_factor <= MAX_CONTRACTION_FACTOR, E_INVALID_FACTOR);
        
        let state = borrow_global_mut<GovernanceState>(@fusd);
        state.pending_action = std::option::some(PendingAction {
            action_type: 2,
            value: new_factor,
            execution_time: timestamp::now_seconds() + TIMELOCK_DURATION,
        });
    }

    /// Execute pending action (Admin only after timelock)
    public entry fun execute_pending_action(admin: &signer) acquires FUSDConfig, GovernanceState {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_ADMIN);
        
        let state = borrow_global_mut<GovernanceState>(@fusd);
        assert!(std::option::is_some(&state.pending_action), E_NO_PENDING_ACTION);
        
        let pending = std::option::extract(&mut state.pending_action);
        assert!(timestamp::now_seconds() >= pending.execution_time, E_TIMELOCK_ACTIVE);
        
        let config = borrow_global_mut<FUSDConfig>(@fusd);

        if (pending.action_type == 1) {
            let old_factor = config.expansion_factor;
            config.expansion_factor = pending.value;
            event::emit_event(&mut config.factor_events, FactorUpdateEvent {
                factor_type: 1,
                old_value: old_factor,
                new_value: pending.value,
                timestamp: timestamp::now_seconds(),
            });
        } else if (pending.action_type == 2) {
            let old_factor = config.contraction_factor;
            config.contraction_factor = pending.value;
            event::emit_event(&mut config.factor_events, FactorUpdateEvent {
                factor_type: 2,
                old_value: old_factor,
                new_value: pending.value,
                timestamp: timestamp::now_seconds(),
            });
        }
    }

    /// Get circuit breaker threshold
    public fun get_circuit_breaker_threshold(): u64 {
        CIRCUIT_BREAKER_THRESHOLD_BPS
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

    // --- Deprecated Functions (Restored for Backward Compatibility) ---

    public entry fun set_expansion_factor(_admin: &signer, _val: u64) {
        abort E_DEPRECATED
    }

    public entry fun set_contraction_factor(_admin: &signer, _val: u64) {
        abort E_DEPRECATED
    }

    public entry fun set_cooldown(_admin: &signer, _val: u64) {
        abort E_DEPRECATED
    }
}
