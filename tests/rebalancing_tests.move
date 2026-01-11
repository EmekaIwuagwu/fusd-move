#[test_only]
module fusd::rebalancing_tests {
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::coin;
    use fusd::fusd_coin;
    use fusd::rebalancing;
    use fusd::oracle_integration;
    use fusd::governance;

    #[test]
    fun test_expansion_when_price_high() {
        let admin = account::create_account_for_test(@fusd);
        
        // Setup time for oracle and timestamp checks
        timestamp::set_time_has_started_for_testing(&admin);
        
        // Init modules
        fusd_coin::init_for_test(&admin);
        fusd_coin::register(&admin);
        governance::initialize(&admin, @fusd, @fusd);
        oracle_integration::init_for_test(&admin);
        rebalancing::initialize_events(&admin);

        // Mint initial supply: 1,000 FUSD
        let initial_supply = 1000 * 100000000;
        let coins = fusd_coin::mint(&admin, initial_supply);
        coin::deposit(signer::address_of(&admin), coins);

        assert!(fusd_coin::get_supply() == initial_supply, 0);

        // Set price to $1.10 (10% over peg)
        oracle_integration::set_price(&admin, 110000000);

        // Execute rebalance
        rebalancing::execute_rebalance(&admin);

        // Check supply expanded
        let new_supply = fusd_coin::get_supply();
        assert!(new_supply > initial_supply, 1);
        
        // Calculation check:
        // Diff = 1.10 - 1.00 = 0.10
        // Threshold = 0.005. Diff > Threshold.
        // Expansion = Diff * Supply * Factor = 0.10 * 1000 * 0.1 = 10 FUSD
        // Expected ~ 1010 FUSD.
        // Formula in code: (price_diff * supply * factor) / target / 10000
        // (10000000 * 100000000000 * 1000) / 100000000 / 10000
        // = 10000000 * 100000000000 * 1000 = 1,000,000,000,000,000,000
        // / 1,000,000,000,000 = 1,000,000,000 (10 FUSD)
        
        assert!(new_supply == initial_supply + 1000000000, 2);
    }

    #[test]
    fun test_contraction_when_price_low() {
        let admin = account::create_account_for_test(@fusd);
        timestamp::set_time_has_started_for_testing(&admin);
        
        fusd_coin::init_for_test(&admin);
        fusd_coin::register(&admin);
        governance::initialize(&admin, @fusd, @fusd);
        oracle_integration::init_for_test(&admin);
        rebalancing::initialize_events(&admin);

        let initial_supply = 1000 * 100000000;
        let coins = fusd_coin::mint(&admin, initial_supply);
        coin::deposit(signer::address_of(&admin), coins);

        // Set price to $0.90 (10% under peg)
        // 0.90 * 10^8 = 90000000
        oracle_integration::set_price(&admin, 90000000);

        // Execute rebalance
        rebalancing::execute_rebalance(&admin);

        // Check supply contracted
        let new_supply = fusd_coin::get_supply();
        assert!(new_supply < initial_supply, 1);

        // Contraction Factor is 0.15
        // Diff = 0.10.
        // Contraction = 0.10 * 1000 * 0.15 = 15 FUSD.
        // Expected ~ 985 FUSD.
        assert!(new_supply == initial_supply - 1500000000, 2);
    }
}
