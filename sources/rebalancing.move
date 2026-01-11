module fusd::rebalancing {
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use fusd::oracle_integration;
    use fusd::fusd_coin;
    use fusd::governance;
    use fusd::events;
    use fusd::liquidity_pool;

    /// Error codes
    const E_COOLDOWN_ACTIVE: u64 = 4001;
    const E_PRICE_STABLE: u64 = 4002;
    const E_NOT_ADMIN: u64 = 4003;
    const E_PAUSED: u64 = 4004;
    const E_INSUFFICIENT_RESERVES: u64 = 4005;

    /// Maximum single rebalance as percentage of total supply (5%)
    const MAX_REBALANCE_PERCENT: u64 = 5;

    struct RebalanceEvents has key {
        expansion_events: event::EventHandle<events::RebalanceExpansion>,
        contraction_events: event::EventHandle<events::RebalanceContraction>,
    }

    public entry fun initialize_events(admin: &signer) {
        if (!exists<RebalanceEvents>(signer::address_of(admin))) {
            move_to(admin, RebalanceEvents {
                expansion_events: account::new_event_handle<events::RebalanceExpansion>(admin),
                contraction_events: account::new_event_handle<events::RebalanceContraction>(admin),
            });
        }
    }

    /// Execute the rebalancing logic with safety checks
    public entry fun execute_rebalance(admin: &signer) acquires RebalanceEvents {
        let admin_addr = signer::address_of(admin);
        
        // Safety checks
        assert!(!governance::is_paused(), E_PAUSED);
        assert!(governance::can_rebalance(), E_COOLDOWN_ACTIVE);
        
        let (target_price, exp_factor, cont_factor, _cooldown, _last_timestamp) = governance::get_config_values();
        
        // Use TWAP for more stable price
        let (price, _) = oracle_integration::get_twap();

        let threshold = target_price * 5 / 1000;

        if (price > target_price + threshold) {
            execute_expansion(admin, admin_addr, price, target_price, exp_factor);
        } else if (price < target_price - threshold) {
            execute_contraction(admin, admin_addr, price, target_price, cont_factor);
        }
    }

    /// Execute expansion (minting)
    fun execute_expansion(
        admin: &signer,
        admin_addr: address,
        price: u64,
        target_price: u64,
        exp_factor: u64
    ) acquires RebalanceEvents {
        let supply = fusd_coin::get_supply();
        let price_diff = price - target_price;
        
        // Calculate amount with overflow protection
        let val = (price_diff as u128) * (supply as u128);
        let amount_u128 = (val * (exp_factor as u128)) / ((target_price as u128) * 10000);
        
        // Check for u64 overflow
        assert!(amount_u128 <= (18446744073709551615 as u128), E_COOLDOWN_ACTIVE);
        let amount_to_mint = (amount_u128 as u64);

        // Apply max rebalance cap
        let max_mint = supply * MAX_REBALANCE_PERCENT / 100;
        if (amount_to_mint > max_mint) {
            amount_to_mint = max_mint;
        };

        if (amount_to_mint > 0) {
             let coins = fusd_coin::mint(admin, amount_to_mint);
             aptos_framework::coin::deposit(admin_addr, coins);

             // Update timestamp BEFORE emitting event
             governance::update_rebalance_timestamp();

             let event_handles = borrow_global_mut<RebalanceEvents>(@fusd);
             event::emit_event(&mut event_handles.expansion_events, events::new_rebalance_expansion(
                 price,
                 fusd_coin::get_supply(),
                 amount_to_mint,
                 timestamp::now_seconds(),
             ));
        }
    }

    /// Execute contraction (burning) - FIXED: Pull from reserves
    fun execute_contraction(
        admin: &signer,
        admin_addr: address,
        price: u64,
        target_price: u64,
        cont_factor: u64
    ) acquires RebalanceEvents {
        let price_diff = target_price - price;
        let supply = fusd_coin::get_supply();
        
        // Calculate amount with overflow protection
        let val = (price_diff as u128) * (supply as u128);
        let amount_u128 = (val * (cont_factor as u128)) / ((target_price as u128) * 10000);
        
        // Check for u64 overflow
        assert!(amount_u128 <= (18446744073709551615 as u128), E_COOLDOWN_ACTIVE);
        let amount_to_burn = (amount_u128 as u64);

        // Apply max rebalance cap
        let max_burn = supply * MAX_REBALANCE_PERCENT / 100;
        if (amount_to_burn > max_burn) {
            amount_to_burn = max_burn;
        };

        if (amount_to_burn > 0) {
             // FIXED CRITICAL-02: Try to burn from reserves first
             let reserves = liquidity_pool::get_fusd_reserves();
             let admin_balance = fusd_coin::balance(admin_addr);
             let total_available = reserves + admin_balance;
             
             assert!(total_available >= amount_to_burn, E_INSUFFICIENT_RESERVES);
             
             let burn_amount = 0u64;
             
             // Burn from reserves first
             if (reserves > 0) {
                 let from_reserves = if (reserves >= amount_to_burn) {
                     amount_to_burn
                 } else {
                     reserves
                 };
                 
                 liquidity_pool::burn_from_reserves(admin, from_reserves);
                 burn_amount = burn_amount + from_reserves;
             };
             
             // Burn remaining from admin balance if needed
             if (burn_amount < amount_to_burn && admin_balance > 0) {
                 let from_admin = amount_to_burn - burn_amount;
                 if (from_admin > admin_balance) {
                     from_admin = admin_balance;
                 };
                 
                 let coins = aptos_framework::coin::withdraw<fusd_coin::FUSD>(admin, from_admin);
                 fusd_coin::burn(admin, coins);
                 burn_amount = burn_amount + from_admin;
             };
             
             // Update timestamp BEFORE emitting event
             if (burn_amount > 0) {
                 governance::update_rebalance_timestamp();
             };
             
             let event_handles = borrow_global_mut<RebalanceEvents>(@fusd);
             event::emit_event(&mut event_handles.contraction_events, events::new_rebalance_contraction(
                 price,
                 fusd_coin::get_supply(),
                 burn_amount,
                 timestamp::now_seconds(),
             ));
        }
    }
}
