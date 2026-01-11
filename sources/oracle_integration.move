module fusd::oracle_integration {
    use std::signer;
    use std::vector;
    use aptos_framework::timestamp;

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 3001;
    const E_STALE_PRICE: u64 = 3002;
    const E_INVALID_PRICE: u64 = 3003;
    const E_PRICE_DEVIATION_TOO_HIGH: u64 = 3004;
    const E_INSUFFICIENT_TWAP_DATA: u64 = 3005;

    /// Maximum price staleness in seconds (60 seconds)
    const MAX_PRICE_STALENESS: u64 = 60;
    
    /// Maximum price deviation (10%)
    const MAX_PRICE_DEVIATION_BPS: u64 = 1000;
    
    /// TWAP window size
    const TWAP_WINDOW: u64 = 3600; // 1 hour
    const MAX_TWAP_ENTRIES: u64 = 60; // Store up to 60 price points

    /// Price entry for TWAP calculation
    struct PriceEntry has store, drop {
        price: u64,
        timestamp: u64,
    }

    /// Price oracle state with TWAP
    struct PriceOracle has key {
        price: u64,              
        last_update_time: u64,
        decimals: u8,
        twap_buffer: vector<PriceEntry>,
    }

    /// Initialize the oracle
    public entry fun initialize(admin: &signer) {
        move_to(admin, PriceOracle {
            price: 100000000,
            last_update_time: timestamp::now_seconds(),
            decimals: 8,
            twap_buffer: vector::empty<PriceEntry>(),
        });
    }

    /// Update price with validation (Admin only)
    public entry fun set_price(admin: &signer, new_price: u64) acquires PriceOracle {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_AUTHORIZED);
        assert!(new_price > 0, E_INVALID_PRICE);
        
        let oracle = borrow_global_mut<PriceOracle>(admin_addr);
        let old_price = oracle.price;
        
        // Validate price deviation (max 10% change)
        let max_price = old_price * (10000 + MAX_PRICE_DEVIATION_BPS) / 10000;
        let min_price = old_price * (10000 - MAX_PRICE_DEVIATION_BPS) / 10000;
        
        assert!(
            new_price >= min_price && new_price <= max_price,
            E_PRICE_DEVIATION_TOO_HIGH
        );
        
        let current_time = timestamp::now_seconds();
        
        // Update TWAP buffer
        vector::push_back(&mut oracle.twap_buffer, PriceEntry {
            price: new_price,
            timestamp: current_time,
        });
        
        // Keep only recent entries
        if (vector::length(&oracle.twap_buffer) > MAX_TWAP_ENTRIES) {
            vector::remove(&mut oracle.twap_buffer, 0);
        };
        
        // Clean old entries outside TWAP window
        clean_old_entries(&mut oracle.twap_buffer, current_time);
        
        oracle.price = new_price;
        oracle.last_update_time = current_time;
    }

    /// Clean entries older than TWAP window
    fun clean_old_entries(buffer: &mut vector<PriceEntry>, current_time: u64) {
        let cutoff_time = if (current_time > TWAP_WINDOW) {
            current_time - TWAP_WINDOW
        } else {
            0
        };
        
        let i = 0;
        let len = vector::length(buffer);
        
        while (i < len) {
            let entry = vector::borrow(buffer, i);
            if (entry.timestamp < cutoff_time) {
                vector::remove(buffer, i);
                len = len - 1;
            } else {
                i = i + 1;
            }
        }
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

    /// Get TWAP (Time-Weighted Average Price)
    public fun get_twap(): (u64, u8) acquires PriceOracle {
        if (exists<PriceOracle>(@fusd)) {
            let oracle = borrow_global<PriceOracle>(@fusd);
            let len = vector::length(&oracle.twap_buffer);
            
            assert!(len > 0, E_INSUFFICIENT_TWAP_DATA);
            
            let sum: u128 = 0;
            let i = 0;
            
            while (i < len) {
                let entry = vector::borrow(&oracle.twap_buffer, i);
                sum = sum + (entry.price as u128);
                i = i + 1;
            };
            
            let twap = ((sum / (len as u128)) as u64);
            (twap, oracle.decimals)
        } else {
            (100000000, 8)
        }
    }

    /// Get price without staleness check (for view functions)
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

    /// Get TWAP buffer size
    public fun get_twap_buffer_size(): u64 acquires PriceOracle {
        if (exists<PriceOracle>(@fusd)) {
            vector::length(&borrow_global<PriceOracle>(@fusd).twap_buffer)
        } else {
            0
        }
    }

    #[test_only]
    public fun init_for_test(admin: &signer) {
        initialize(admin);
    }
}
