#[test_only]
module fusd::security_tests {
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::coin::{Self, Coin};
    use fusd::fusd_coin::{Self, FUSD};
    use fusd::rebalancing;
    use fusd::oracle_integration;
    use fusd::governance;
    use fusd::liquidity_pool;

    struct CoinHolder has key {
        coins: Coin<FUSD>,
    }

    fun hold_coins(user: &signer, coins: Coin<FUSD>) {
        move_to(user, CoinHolder { coins });
    }

    #[test]
    fun test_timelock_enforcement() {
        let admin = account::create_account_for_test(@fusd);
        let framework = account::create_account_for_test(@0x1);
        timestamp::set_time_has_started_for_testing(&framework);

        fusd_coin::init_for_test(&admin);
        governance::initialize(&admin, @fusd, @fusd);

        // Propose new factor
        governance::propose_expansion_factor(&admin, 2000); // 20%

        // Factor should still be old value
        let (_, expansion, _, _, _) = governance::get_config_values();
        assert!(expansion == 1000, 1);

        // Fast forward 12 hours (43200 seconds)
        timestamp::fast_forward_seconds(43200);
        
        // Still old value
        let (_, expansion_2, _, _, _) = governance::get_config_values();
        assert!(expansion_2 == 1000, 2);

        // Fast forward another 13 hours (Total > 24h)
        timestamp::fast_forward_seconds(46800);
        
        governance::execute_pending_action(&admin);
        
        let (_, expansion_3, _, _, _) = governance::get_config_values();
        assert!(expansion_3 == 2000, 3);
    }

    #[test]
    fun test_circuit_breaker_activation() {
        let admin = account::create_account_for_test(@fusd);
        let framework = account::create_account_for_test(@0x1);
        timestamp::set_time_has_started_for_testing(&framework);

        fusd_coin::init_for_test(&admin);
        governance::initialize(&admin, @fusd, @fusd);
        oracle_integration::init_for_test(&admin);
        rebalancing::initialize_events(&admin);

        // Set an extreme price gradually (max 10% change per call)
        oracle_integration::set_price(&admin, 110000000); // $1.10
        oracle_integration::set_price(&admin, 121000000); // $1.21
        oracle_integration::set_price(&admin, 130000000); // $1.30 (> 25% deviation from $1.00)
        
        // Push price to TWAP buffer
        let i = 0;
        while (i < 10) {
            oracle_integration::set_price(&admin, 130000000);
            i = i + 1;
        };

        // Try to rebalance
        rebalancing::execute_rebalance(&admin);

        // Check if circuit breaker triggered
        assert!(governance::is_circuit_breaker_triggered(), 4);
        assert!(governance::is_paused(), 5);
    }

    #[test]
    fun test_insurance_fund_flow() {
        let admin = account::create_account_for_test(@fusd);
        let framework = account::create_account_for_test(@0x1);
        timestamp::set_time_has_started_for_testing(&framework);

        fusd_coin::init_for_test(&admin);
        fusd_coin::register(&admin);
        governance::initialize(&admin, @fusd, @fusd);
        oracle_integration::init_for_test(&admin);
        rebalancing::initialize_events(&admin);
        liquidity_pool::initialize(&admin);

        // Initial supply (500 FUSD)
        let initial_supply = 500 * 100000000;
        let coins = fusd_coin::mint(&admin, initial_supply);
        
        // bypass coin::deposit to avoid metadata issue
        hold_coins(&admin, coins);

        // Expansion to fill Insurance Fund
        oracle_integration::set_price(&admin, 110000000); // $1.10
        rebalancing::execute_rebalance(&admin);

        let fund_balance = liquidity_pool::get_insurance_balance();
        assert!(fund_balance > 0, 6);

        // Contraction using Insurance Fund
        timestamp::fast_forward_seconds(33000); // Cooldown (6h+)
        
        oracle_integration::set_price(&admin, 90000000); // $0.90
        
        let pre_burn_fund = liquidity_pool::get_insurance_balance();
        rebalancing::execute_rebalance(&admin);
        let post_burn_fund = liquidity_pool::get_insurance_balance();
        
        assert!(post_burn_fund < pre_burn_fund, 7);
    }
}
