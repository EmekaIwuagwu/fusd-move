module fusd::gas_abstraction {
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use fusd::fusd_coin::FUSD;

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_DAILY_LIMIT_EXCEEDED: u64 = 2;
    const E_INSUFFICIENT_FUSD: u64 = 3;
    const E_INVALID_PRICE: u64 = 4;

    /// Convenience fee in basis points (2%)
    const CONVENIENCE_FEE_BPS: u64 = 200;

    /// Daily subsidy cap per user (in FUSD, 8 decimals)
    const DAILY_SUBSIDY_CAP: u64 = 10000000000; // 100 FUSD

    /// Seconds in a day
    const SECONDS_PER_DAY: u64 = 86400;

    struct GasConfig has key {
        treasury: address,
        apt_price_usd: u64,
    }

    struct UserGasUsage has key {
        daily_usage: u64,
        last_reset_timestamp: u64,
    }

    /// Initialize gas abstraction
    public entry fun initialize(admin: &signer, treasury: address) {
        move_to(admin, GasConfig { 
            treasury, 
            apt_price_usd: 1000000000
        });
    }

    /// User pays FUSD to cover gas fees
    public entry fun repay_gas_in_fusd(user: &signer, estimated_gas_octas: u64) acquires GasConfig, UserGasUsage {
        let user_addr = signer::address_of(user);
        let config = borrow_global<GasConfig>(@fusd);
        
        let amount_fusd = (estimated_gas_octas * config.apt_price_usd) / 100000000;
        let total_amount = amount_fusd * (10000 + CONVENIENCE_FEE_BPS) / 10000;

        if (!exists<UserGasUsage>(user_addr)) {
            move_to(user, UserGasUsage {
                daily_usage: 0,
                last_reset_timestamp: timestamp::now_seconds(),
            });
        };

        let usage = borrow_global_mut<UserGasUsage>(user_addr);
        let current_time = timestamp::now_seconds();
        
        if (current_time - usage.last_reset_timestamp >= SECONDS_PER_DAY) {
            usage.daily_usage = 0;
            usage.last_reset_timestamp = current_time;
        };

        assert!(usage.daily_usage + total_amount <= DAILY_SUBSIDY_CAP, E_DAILY_LIMIT_EXCEEDED);
        assert!(coin::balance<FUSD>(user_addr) >= total_amount, E_INSUFFICIENT_FUSD);

        if (total_amount > 0) {
            coin::transfer<FUSD>(user, config.treasury, total_amount);
            usage.daily_usage = usage.daily_usage + total_amount;
        };
    }

    /// Update APT price (Admin only)
    public entry fun set_apt_price(admin: &signer, price: u64) acquires GasConfig {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_AUTHORIZED);
        assert!(price > 0, E_INVALID_PRICE);
        
        let config = borrow_global_mut<GasConfig>(@fusd);
        config.apt_price_usd = price;
    }

    /// Get current APT price
    public fun get_apt_price(): u64 acquires GasConfig {
        if (exists<GasConfig>(@fusd)) {
            borrow_global<GasConfig>(@fusd).apt_price_usd
        } else {
            1000000000
        }
    }

    /// Get user's daily gas usage
    public fun get_daily_usage(user: address): u64 acquires UserGasUsage {
        if (exists<UserGasUsage>(user)) {
            let usage = borrow_global<UserGasUsage>(user);
            let current_time = timestamp::now_seconds();
            
            if (current_time - usage.last_reset_timestamp >= SECONDS_PER_DAY) {
                0
            } else {
                usage.daily_usage
            }
        } else {
            0
        }
    }

    /// Calculate FUSD cost for gas
    public fun calculate_fusd_cost(gas_octas: u64): u64 acquires GasConfig {
        let config = borrow_global<GasConfig>(@fusd);
        let base_amount = (gas_octas * config.apt_price_usd) / 100000000;
        base_amount * (10000 + CONVENIENCE_FEE_BPS) / 10000
    }
}
