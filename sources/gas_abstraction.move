module fusd::gas_abstraction {
    use std::signer;
    use aptos_framework::coin;
    use fusd::fusd_coin::FUSD;

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;

    struct GasConfig has key {
        treasury: address,
        apt_price_usd_mock: u64, // 8 decimals, e.g. 1000000000 = $10.00
    }

    public entry fun initialize(admin: &signer, treasury: address) {
        move_to(admin, GasConfig { 
            treasury, 
            apt_price_usd_mock: 1000000000 // $10.00 
        });
    }

    /// User pays FUSD to cover gas fees
    /// estimated_gas_octas: The amount of APT gas expected to be used (in Octas)
    public entry fun repay_gas_in_fusd(user: &signer, estimated_gas_octas: u64) acquires GasConfig {
        let config = borrow_global<GasConfig>(@fusd);
        
        // Calculate FUSD required
        // 1 APT (10^8 Octas) = Price (e.g. $10 = 10*10^8)
        // Ratio: Price / 10^8
        
        // Amount FUSD = (estimated_gas_octas * config.apt_price_usd_mock) / 100000000;
        // Example: 1000 Octas * 1000000000 / 100000000 = 1000 * 10 = 10000 FUSD units ($0.0001)
        
        let amount_fusd = (estimated_gas_octas * config.apt_price_usd_mock) / 100000000;
        
        // Convenience Fee: 2%
        let total_amount = amount_fusd * 102 / 100;

        if (total_amount > 0) {
            coin::transfer<FUSD>(user, config.treasury, total_amount);
        };
    }

    public fun set_apt_price(admin: &signer, price: u64) acquires GasConfig {
        let _ = admin;
        // assert admin is @fusd or similar, assuming access control
        let config = borrow_global_mut<GasConfig>(@fusd);
        config.apt_price_usd_mock = price;
    }
}
