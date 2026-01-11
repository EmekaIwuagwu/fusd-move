module fusd::rebalancing {
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use fusd::oracle_integration;
    use fusd::fusd_coin;
    use fusd::governance;
    use fusd::events::{RebalanceExpansion, RebalanceContraction};

    /// Error codes
    const E_COOLDOWN_ACTIVE: u64 = 1;
    const E_PRICE_STABLE: u64 = 2;
    const E_NOT_ADMIN: u64 = 3;

    struct RebalanceEvents has key {
        expansion_events: event::EventHandle<RebalanceExpansion>,
        contraction_events: event::EventHandle<RebalanceContraction>,
    }

    public entry fun initialize_events(admin: &signer) {
        if (!exists<RebalanceEvents>(signer::address_of(admin))) {
            move_to(admin, RebalanceEvents {
                expansion_events: account::new_event_handle<RebalanceExpansion>(admin),
                contraction_events: account::new_event_handle<RebalanceContraction>(admin),
            });
        }
    }

    /// Execute the rebalancing logic
    public entry fun execute_rebalance(admin: &signer) acquires RebalanceEvents {
        let admin_addr = signer::address_of(admin);
        
        // 1. Check Governance Config (Cooldown, etc.)
        let (target_price, exp_factor, cont_factor, cooldown) = governance::get_config_values();
        // TODO: Check last timestamp (need to update governance to store/update timestamp)
        
        // 2. Get Price
        let (price, _) = oracle_integration::get_price();

        // 3. Calculate deviation
        // Threshold 0.5% = 0.005 * 10^8 = 500,000
        let threshold = target_price * 5 / 1000;

        if (price > target_price + threshold) {
            // Expansion
            // Amount = (Price - Target) * Supply * Factor
            // Note: Factors are scaled (e.g. 1000 = 10%)
            // We need supply.
            let supply = fusd_coin::get_supply();
            
            // diff = price - target (e.g. $1.05 - $1.00 = $0.05 = 5000000)
            let price_diff = price - target_price;
            
            // amount = (price_diff * supply * 1000) / (target_price * 10000) ??
            // formula: (price - 1) * supply * factor
            // factor is e.g. 0.1.
            // (price_diff / target_price) * supply * (exp_factor / 10000)
            
            let val = (price_diff as u128) * (supply as u128);
            let amount_u128 = val * (exp_factor as u128) / 10000 / (target_price as u128);
            let amount_to_mint = (amount_u128 as u64);

            if (amount_to_mint > 0) {
                 let coins = fusd_coin::mint(admin, amount_to_mint);
                 // Distribute: 40% Pools, 40% Stakers, 20% Treasury
                 // For now, just deposit to admin (treasury)
                 aptos_framework::coin::deposit(admin_addr, coins);

                 // Emit Event
                 let event_handles = borrow_global_mut<RebalanceEvents>(@fusd);
                 event::emit_event(&mut event_handles.expansion_events, fusd::events::new_rebalance_expansion(
                     price,
                     fusd_coin::get_supply(),
                     amount_to_mint,
                     timestamp::now_seconds(),
                 ));
            }

        } else if (price < target_price - threshold) {
            // Contraction
            let price_diff = target_price - price;
            // let supply = fusd_coin::get_supply(); // Already defined in previous block? No, lexical scope. 
            // Wait, supply was defined in `if` block? 
            // `let supply = ...` inside `if` block is not visible in `else if`.
            let supply = fusd_coin::get_supply();
            
            let val = (price_diff as u128) * (supply as u128);
            let amount_u128 = val * (cont_factor as u128) / 10000 / (target_price as u128);
            let amount_to_burn = (amount_u128 as u64);

            if (amount_to_burn > 0) {
                 // Must have coins to burn. Protocol should burn from treasury or pools.
                 // For now, try burn from admin (treasury)
                 // NOTE: If admin has no coins, this fails.
                 // Real impl pulls from Liquidity Pools.
                 
                 // Check balance
                 let balance = fusd_coin::balance(admin_addr);
                 let burn_amount = if (balance < amount_to_burn) { balance } else { amount_to_burn };
                 
                 if (burn_amount > 0) {
                     let coins = aptos_framework::coin::withdraw<fusd_coin::FUSD>(admin, burn_amount);
                     fusd_coin::burn(admin, coins);
                 };
                 
                 // Emit Event
                 let event_handles = borrow_global_mut<RebalanceEvents>(@fusd);
                 event::emit_event(&mut event_handles.contraction_events, fusd::events::new_rebalance_contraction(
                     price,
                     fusd_coin::get_supply(),
                     burn_amount,
                     timestamp::now_seconds(),
                 ));
            }
        } else {
             // Stable
        }
    }
}
