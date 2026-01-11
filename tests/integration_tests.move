#[test_only]
module fusd::integration_tests {
    use std::signer;
    use std::debug;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::coin;
    use fusd::fusd_coin;
    use fusd::rebalancing;
    use fusd::oracle_integration;
    use fusd::governance;
    use fusd::gas_abstraction;

    #[test]
    fun test_full_flow_stablecoin_lifecycle() {
        let admin = account::create_account_for_test(@fusd);
        let user = account::create_account_for_test(@0xA);
        
        // Setup environment (Timestamp, Genesis if needed)
        // Note: Using 0x1 for timestamp setup
        let framework = account::create_account_for_test(@0x1);
        timestamp::set_time_has_started_for_testing(&framework);

        // 1. Initialize Protocol
        fusd_coin::init_for_test(&admin);
        coin::register<fusd_coin::FUSD>(&user); 
        coin::register<fusd_coin::FUSD>(&admin);

        governance::initialize(&admin, @fusd, @fusd);
        oracle_integration::init_for_test(&admin);
        rebalancing::initialize_events(&admin);
        gas_abstraction::initialize(&admin, @fusd);

        // 2. Mint Genesis Supply (500 FUSD)
        let initial_supply = 500 * 100000000;
        let coins = fusd_coin::mint(&admin, initial_supply);
        coin::deposit(signer::address_of(&admin), coins);

        assert!(fusd_coin::get_supply() == initial_supply, 0);

        // 3. Distribute to User
        coin::transfer<fusd_coin::FUSD>(&admin, signer::address_of(&user), 1000000000); // 10 FUSD
        assert!(fusd_coin::balance(signer::address_of(&user)) == 1000000000, 1);

        // 4. Gas Abstraction Usage
        // User pays gas in FUSD. Estimated gas: 5000 Octas.
        // Price: 1 APT ($10) = 10 FUSD. Gas = 5000 Octas = 50000 FUSD units.
        // Fee: 2%. Total = 51000.
        gas_abstraction::repay_gas_in_fusd(&user, 5000);
        
        let expected_deduction = 50000 + (50000 * 2 / 100); // 51000
        let new_balance = fusd_coin::balance(signer::address_of(&user));
        assert!(new_balance == 1000000000 - expected_deduction, 2);

        // 5. Rebalancing Event (Expansion)
        // Price moves to $1.10
        oracle_integration::set_price(&admin, 110000000);
        
        let pre_rebalance_supply = fusd_coin::get_supply();
        rebalancing::execute_rebalance(&admin);
        
        let post_rebalance_supply = fusd_coin::get_supply();
        assert!(post_rebalance_supply > pre_rebalance_supply, 3);
        
        // 6. Rebalancing Event (Contraction)
        // Price crashes to $0.80
        oracle_integration::set_price(&admin, 80000000);
        
        rebalancing::execute_rebalance(&admin);
        assert!(fusd_coin::get_supply() < post_rebalance_supply, 4);
    }
}
