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
    const E_CIRCUIT_BREAKER_TRIGGERED: u64 = 4006;

    /// Maximum single rebalance as percentage of total supply (5%)
    const MAX_REBALANCE_PERCENT: u64 = 5;
    
    /// Insurance Fund Fee (1%)
    const INSURANCE_FEE_BPS: u64 = 100;

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
        // Safety checks
        assert!(!governance::is_paused(), E_PAUSED);
        assert!(governance::can_rebalance(), E_COOLDOWN_ACTIVE);
        
        let (target_price, exp_factor, cont_factor, _cooldown, _last_timestamp) = governance::get_config_values();
        
        // Use TWAP for more stable price
        let (price, _) = oracle_integration::get_twap();

        // Circuit Breaker Check
        let threshold_bps = governance::get_circuit_breaker_threshold();
        let deviation = if (price > target_price) { price - target_price } else { target_price - price };
        let deviation_bps = (deviation as u128) * 10000 / (target_price as u128);
        
        if (deviation_bps > (threshold_bps as u128)) {
            governance::trigger_circuit_breaker();
            return
        };

        let price_threshold = target_price * 5 / 1000;

        if (price > target_price + price_threshold) {
            execute_expansion(admin, price, target_price, exp_factor);
        } else if (price < target_price - price_threshold) {
            execute_contraction(admin, price, target_price, cont_factor);
        }
    }

    /// Execute expansion (minting)
    fun execute_expansion(
        admin: &signer,
        price: u64,
        target_price: u64,
        exp_factor: u64
    ) acquires RebalanceEvents {
        let admin_addr = signer::address_of(admin);
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
             // Mint for rebalancing
             let coins = fusd_coin::mint(admin, amount_to_mint);
             aptos_framework::coin::deposit(admin_addr, coins);
             
             // Mint Insurance Fee
             let insurance_fee = (amount_to_mint as u128) * (INSURANCE_FEE_BPS as u128) / 10000;
             if (insurance_fee > 0) {
                 let fee_coins = fusd_coin::mint(admin, (insurance_fee as u64));
                 liquidity_pool::deposit_to_insurance_fund(fee_coins);
             };

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

    /// Execute contraction (burning) - UPDATED: Use Insurance Fund & Reserves
    fun execute_contraction(
        admin: &signer,
        price: u64,
        target_price: u64,
        cont_factor: u64
    ) acquires RebalanceEvents {
        let admin_addr = signer::address_of(admin);
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
             let burned_so_far = 0u64;
             
             // 1. Try Insurance Fund first (Protocol safety net)
             let insurance_coins = liquidity_pool::pull_from_insurance_fund(amount_to_burn);
             let from_insurance = aptos_framework::coin::value(&insurance_coins);
             if (from_insurance > 0) {
                 fusd_coin::burn_from_system(insurance_coins);
                 burned_so_far = burned_so_far + from_insurance;
             } else {
                 aptos_framework::coin::destroy_zero(insurance_coins);
             };
             
             // 2. Try regular reserves
             if (burned_so_far < amount_to_burn) {
                 let remaining = amount_to_burn - burned_so_far;
                 let reserves = liquidity_pool::get_fusd_reserves();
                 let from_reserves = if (reserves >= remaining) { remaining } else { reserves };
                 
                 if (from_reserves > 0) {
                     liquidity_pool::burn_from_reserves(admin, from_reserves);
                     burned_so_far = burned_so_far + from_reserves;
                 };
             };
             
             // 3. Last resort: Admin balance
             if (burned_so_far < amount_to_burn) {
                 let remaining = amount_to_burn - burned_so_far;
                 let admin_balance = fusd_coin::balance(admin_addr);
                 let from_admin = if (admin_balance >= remaining) { remaining } else { admin_balance };
                 
                 if (from_admin > 0) {
                     let coins = aptos_framework::coin::withdraw<fusd_coin::FUSD>(admin, from_admin);
                     fusd_coin::burn(admin, coins);
                     burned_so_far = burned_so_far + from_admin;
                 };
             };
             
             assert!(burned_so_far > 0, E_INSUFFICIENT_RESERVES);
             
             // Update timestamp
             governance::update_rebalance_timestamp();
             
             let event_handles = borrow_global_mut<RebalanceEvents>(@fusd);
             event::emit_event(&mut event_handles.contraction_events, events::new_rebalance_contraction(
                 price,
                 fusd_coin::get_supply(),
                 burned_so_far,
                 timestamp::now_seconds(),
             ));
        }
    }
}
