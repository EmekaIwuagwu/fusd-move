module fusd::gas_abstraction {
    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;
    use std::signer;
    use fusd::fusd_coin::FUSD;

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 7001;
    const E_DAILY_LIMIT_EXCEEDED: u64 = 7002;
    const E_INSUFFICIENT_FUSD: u64 = 7003;
    const E_INVALID_PRICE: u64 = 7004;
    const E_ZERO_AMOUNT: u64 = 7005;

    /// Convenience fee in basis points (2%)
    const CONVENIENCE_FEE_BPS: u64 = 200;

    /// Daily subsidy cap per user (in FUSD, 8 decimals)
    const DAILY_SUBSIDY_CAP: u64 = 10000000000; // 100 FUSD

    /// Seconds in a day
    const SECONDS_PER_DAY: u64 = 86400;

    /// Events
    struct GasPaymentEvent has drop, store {
        user: address,
        gas_octas: u64,
        fusd_paid: u64,
        timestamp: u64,
    }

    struct GasConfig has key {
        treasury: address,
        apt_price_usd: u64,
        payment_events: EventHandle<GasPaymentEvent>,
    }

    struct UserGasUsage has key {
        daily_usage: u64,
        last_reset_day: u64, // Store day number instead of timestamp
    }

    /// Initialize gas abstraction
    public entry fun initialize(admin: &signer, treasury: address) {
        move_to(admin, GasConfig { 
            treasury, 
            apt_price_usd: 1000000000,
            payment_events: account::new_event_handle<GasPaymentEvent>(admin),
        });
    }

    /// User pays FUSD to cover gas fees
    public entry fun repay_gas_in_fusd(user: &signer, estimated_gas_octas: u64) 
    acquires GasConfig, UserGasUsage {
        let user_addr = signer::address_of(user);
        let config = borrow_global_mut<GasConfig>(@fusd);
        
        assert!(estimated_gas_octas > 0, E_ZERO_AMOUNT);
        
        // Calculate FUSD cost
        let amount_fusd = (estimated_gas_octas * config.apt_price_usd) / 100000000;
        let total_amount = amount_fusd * (10000 + CONVENIENCE_FEE_BPS) / 10000;

        assert!(total_amount > 0, E_ZERO_AMOUNT);

        // Initialize or get user usage
        if (!exists<UserGasUsage>(user_addr)) {
            move_to(user, UserGasUsage {
                daily_usage: 0,
                last_reset_day: get_current_day(),
            });
        };

        let usage = borrow_global_mut<UserGasUsage>(user_addr);
        let current_day = get_current_day();
        
        // Reset if new day (fixed UTC boundary)
        if (current_day > usage.last_reset_day) {
            usage.daily_usage = 0;
            usage.last_reset_day = current_day;
        };

        // Check daily limit
        assert!(usage.daily_usage + total_amount <= DAILY_SUBSIDY_CAP, E_DAILY_LIMIT_EXCEEDED);
        assert!(coin::balance<FUSD>(user_addr) >= total_amount, E_INSUFFICIENT_FUSD);

        // Update usage BEFORE external call
        usage.daily_usage = usage.daily_usage + total_amount;

        // External call LAST
        coin::transfer<FUSD>(user, config.treasury, total_amount);
        
        // Emit event
        event::emit_event(&mut config.payment_events, GasPaymentEvent {
            user: user_addr,
            gas_octas: estimated_gas_octas,
            fusd_paid: total_amount,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// Get current day number (UTC)
    fun get_current_day(): u64 {
        timestamp::now_seconds() / SECONDS_PER_DAY
    }

    /// Update APT price with validation (Admin only)
    public entry fun set_apt_price(admin: &signer, price: u64) acquires GasConfig {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_AUTHORIZED);
        assert!(price > 0, E_INVALID_PRICE);
        
        // Validate price is reasonable (between $1 and $1000)
        assert!(price >= 100000000 && price <= 100000000000, E_INVALID_PRICE);
        
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
            let current_day = get_current_day();
            
            if (current_day > usage.last_reset_day) {
                0
            } else {
                usage.daily_usage
            }
        } else {
            0
        }
    }

    /// Get remaining daily limit for user
    public fun get_remaining_limit(user: address): u64 acquires UserGasUsage {
        let used = get_daily_usage(user);
        if (used >= DAILY_SUBSIDY_CAP) {
            0
        } else {
            DAILY_SUBSIDY_CAP - used
        }
    }

    /// Calculate FUSD cost for gas
    public fun calculate_fusd_cost(gas_octas: u64): u64 acquires GasConfig {
        let config = borrow_global<GasConfig>(@fusd);
        let base_amount = (gas_octas * config.apt_price_usd) / 100000000;
        base_amount * (10000 + CONVENIENCE_FEE_BPS) / 10000
    }
}
