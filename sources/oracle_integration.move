module fusd::oracle_integration {
    use std::signer;
    use aptos_framework::timestamp;

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_STALE_PRICE: u64 = 2;
    const E_INVALID_PRICE: u64 = 3;

    /// Maximum price staleness in seconds (60 seconds)
    const MAX_PRICE_STALENESS: u64 = 60;

    /// Price oracle state
    struct PriceOracle has key {
        price: u64,              
        last_update_time: u64,
        decimals: u8,
    }

    /// Initialize the oracle
    public entry fun initialize(admin: &signer) {
        move_to(admin, PriceOracle {
            price: 100000000,
            last_update_time: timestamp::now_seconds(),
            decimals: 8,
        });
    }

    /// Update price (Admin only)
    public entry fun set_price(admin: &signer, new_price: u64) acquires PriceOracle {
        let admin_addr = signer::address_of(admin);
        assert!(exists<PriceOracle>(admin_addr), E_NOT_AUTHORIZED);
        assert!(new_price > 0, E_INVALID_PRICE);
        
        let oracle = borrow_global_mut<PriceOracle>(admin_addr);
        oracle.price = new_price;
        oracle.last_update_time = timestamp::now_seconds();
    }

    /// Get current price with staleness check
    public fun get_price(): (u64, u8) acquires PriceOracle {
        if (exists<PriceOracle>(@fusd)) {
            let oracle = borrow_global<PriceOracle>(@fusd);
            let current_time = timestamp::now_seconds();
            
            assert!(
                current_time - oracle.last_update_time < MAX_PRICE_STALENESS, 
                E_STALE_PRICE
            );
             
            (oracle.price, oracle.decimals)
        } else {
            (100000000, 8)
        }
    }

    /// Get price without staleness check (for testing)
    public fun get_price_unchecked(): (u64, u8) acquires PriceOracle {
        if (exists<PriceOracle>(@fusd)) {
            let oracle = borrow_global<PriceOracle>(@fusd);
            (oracle.price, oracle.decimals)
        } else {
            (100000000, 8)
        }
    }

    /// Check if price is stale
    public fun is_price_stale(): bool acquires PriceOracle {
        if (exists<PriceOracle>(@fusd)) {
            let oracle = borrow_global<PriceOracle>(@fusd);
            let current_time = timestamp::now_seconds();
            (current_time - oracle.last_update_time) >= MAX_PRICE_STALENESS
        } else {
            false
        }
    }

    #[test_only]
    public fun init_for_test(admin: &signer) {
        initialize(admin);
    }
}
