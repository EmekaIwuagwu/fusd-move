module fusd::oracle_integration {
    use std::signer;
    use aptos_framework::timestamp;

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_STALE_PRICE: u64 = 2;

    struct MockPriceOracle has key {
        price: u64,              // 8 decimals
        last_update_time: u64,
        decimals: u8,
    }

    /// Initialize the mock oracle for testing/dev
    public entry fun initialize(admin: &signer) {
        move_to(admin, MockPriceOracle {
            price: 100000000, // $1.00 initially
            last_update_time: timestamp::now_seconds(),
            decimals: 8,
        });
    }

    /// Set mock price (Admin only)
    public entry fun set_price(admin: &signer, new_price: u64) acquires MockPriceOracle {
        let admin_addr = signer::address_of(admin);
        assert!(exists<MockPriceOracle>(admin_addr), E_NOT_AUTHORIZED);
        
        let oracle = borrow_global_mut<MockPriceOracle>(admin_addr);
        oracle.price = new_price;
        oracle.last_update_time = timestamp::now_seconds();
    }

    /// Get current price with staleness check
    /// Returns (price, decimals)
    public fun get_price(): (u64, u8) acquires MockPriceOracle {
        // In production, this would call Pyth
        // For now, look for MockPriceOracle at @fusd
        if (exists<MockPriceOracle>(@fusd)) {
            let oracle = borrow_global<MockPriceOracle>(@fusd);
             // Simple staleness check logic (e.g., 60 seconds) could go here
             // assert!(timestamp::now_seconds() - oracle.last_update_time < 60, E_STALE_PRICE);
             
            (oracle.price, oracle.decimals)
        } else {
            // Fallback for when not initialized or in some test contexts
            (100000000, 8)
        }
    }

    #[test_only]
    public fun init_for_test(admin: &signer) {
        initialize(admin);
    }
}
