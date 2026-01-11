module fusd::rebalancing {
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use fusd::oracle_integration;
    use fusd::fusd_coin;
    use fusd::governance;
    use fusd::events;

    /// Error codes
    const E_COOLDOWN_ACTIVE: u64 = 1;
    const E_PRICE_STABLE: u64 = 2;
    const E_NOT_ADMIN: u64 = 3;
    const E_PAUSED: u64 = 4;

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

    /// Execute the rebalancing logic
    public entry fun execute_rebalance(admin: &signer) acquires RebalanceEvents {
        let admin_addr = signer::address_of(admin);
        
        assert!(!governance::is_paused(), E_PAUSED);
        assert!(governance::can_rebalance(), E_COOLDOWN_ACTIVE);
        
        let (target_price, exp_factor, cont_factor, _cooldown, _last_timestamp) = governance::get_config_values();
        
        let (price, _) = oracle_integration::get_price();

        let threshold = target_price * 5 / 1000;

        if (price > target_price + threshold) {
            let supply = fusd_coin::get_supply();
            let price_diff = price - target_price;
            
            let val = (price_diff as u128) * (supply as u128);
            let amount_u128 = val * (exp_factor as u128) / 10000 / (target_price as u128);
            let amount_to_mint = (amount_u128 as u64);

            let max_mint = supply * MAX_REBALANCE_PERCENT / 100;
            if (amount_to_mint > max_mint) {
                amount_to_mint = max_mint;
            };

            if (amount_to_mint > 0) {
                 let coins = fusd_coin::mint(admin, amount_to_mint);
                 aptos_framework::coin::deposit(admin_addr, coins);

                 governance::update_rebalance_timestamp();

                 let event_handles = borrow_global_mut<RebalanceEvents>(@fusd);
                 event::emit_event(&mut event_handles.expansion_events, events::new_rebalance_expansion(
                     price,
                     fusd_coin::get_supply(),
                     amount_to_mint,
                     timestamp::now_seconds(),
                 ));
            }

        } else if (price < target_price - threshold) {
            let price_diff = target_price - price;
            let supply = fusd_coin::get_supply();
            
            let val = (price_diff as u128) * (supply as u128);
            let amount_u128 = val * (cont_factor as u128) / 10000 / (target_price as u128);
            let amount_to_burn = (amount_u128 as u64);

            let max_burn = supply * MAX_REBALANCE_PERCENT / 100;
            if (amount_to_burn > max_burn) {
                amount_to_burn = max_burn;
            };

            if (amount_to_burn > 0) {
                 let balance = fusd_coin::balance(admin_addr);
                 let burn_amount = if (balance < amount_to_burn) { balance } else { amount_to_burn };
                 
                 if (burn_amount > 0) {
                     let coins = aptos_framework::coin::withdraw<fusd_coin::FUSD>(admin, burn_amount);
                     fusd_coin::burn(admin, coins);
                     
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
}
