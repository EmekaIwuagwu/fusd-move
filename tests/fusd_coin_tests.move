#[test_only]
module fusd::fusd_coin_tests {
    use std::signer;
    use std::option;
    use aptos_framework::coin;
    use aptos_framework::account;
    use fusd::fusd_coin::{Self, FUSD};

    #[test]
    fun test_initialize_coin() {
        let admin = account::create_account_for_test(@fusd);
        fusd_coin::init_for_test(&admin);
        
        assert!(coin::is_coin_initialized<FUSD>(), 0);
    }

    #[test]
    fun test_mint_to_account() {
        let admin = account::create_account_for_test(@fusd);
        let user = account::create_account_for_test(@0x123);
        
        fusd_coin::init_for_test(&admin);
        fusd_coin::register(&user);
        
        let coins = fusd_coin::mint(&admin, 1000);
        coin::deposit(signer::address_of(&user), coins);
        
        assert!(coin::balance<FUSD>(signer::address_of(&user)) == 1000, 1);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = fusd::fusd_coin)]
    fun test_unauthorized_mint_fails() {
        let admin = account::create_account_for_test(@fusd);
        let user = account::create_account_for_test(@0x123);
        
        fusd_coin::init_for_test(&admin);
        
        // User tries to mint
        let coins = fusd_coin::mint(&user, 1000);
        coin::destroy_zero(coins);
    }
    
    #[test]
    fun test_burn_tokens() {
        let admin = account::create_account_for_test(@fusd);
        fusd_coin::init_for_test(&admin);
        
        let coins = fusd_coin::mint(&admin, 1000);
        fusd_coin::burn(&admin, coins);
        
        let supply_opt = coin::supply<FUSD>();
        assert!(option::is_some(&supply_opt), 2);
        assert!(*option::borrow(&supply_opt) == 0, 3);
    }

    #[test]
    fun test_transfer_between_accounts() {
        let admin = account::create_account_for_test(@fusd);
        let alice = account::create_account_for_test(@0xA);
        let bob = account::create_account_for_test(@0xB);

        fusd_coin::init_for_test(&admin);
        fusd_coin::register(&alice);
        fusd_coin::register(&bob);

        let coins = fusd_coin::mint(&admin, 500);
        coin::deposit(signer::address_of(&alice), coins);

        coin::transfer<FUSD>(&alice, signer::address_of(&bob), 200);

        assert!(coin::balance<FUSD>(signer::address_of(&alice)) == 300, 4);
        assert!(coin::balance<FUSD>(signer::address_of(&bob)) == 200, 5);
    }
}
