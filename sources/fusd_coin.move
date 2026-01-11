module fusd::fusd_coin {
    use std::string;
    use std::signer;
    use aptos_framework::coin::{Self, BurnCapability, FreezeCapability, MintCapability};
    
    /// The FUSD token marker
    struct FUSD has key {}

    /// Storage for authorities to manage the FUSD coin
    struct FUSDManagement has key {
        burn_cap: BurnCapability<FUSD>,
        freeze_cap: FreezeCapability<FUSD>,
        mint_cap: MintCapability<FUSD>,
    }

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;

    /// Initialize the FUSD coin
    public entry fun initialize(admin: &signer) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<FUSD>(
            admin,
            string::utf8(b"FUSD Stablecoin"),
            string::utf8(b"FUSD"),
            8,
            true,
        );

        move_to(admin, FUSDManagement {
            burn_cap,
            freeze_cap,
            mint_cap,
        });
    }

    /// Mint FUSD tokens. 
    /// Can only be called by the admin currently.
    public fun mint(admin: &signer, amount: u64): aptos_framework::coin::Coin<FUSD> acquires FUSDManagement {
        let admin_addr = signer::address_of(admin);
        assert!(exists<FUSDManagement>(admin_addr), E_NOT_AUTHORIZED);
        
        let caps = borrow_global<FUSDManagement>(admin_addr);
        coin::mint(amount, &caps.mint_cap)
    }

    /// Burn FUSD tokens.
    public fun burn(admin: &signer, coins: aptos_framework::coin::Coin<FUSD>) acquires FUSDManagement {
        let admin_addr = signer::address_of(admin);
        assert!(exists<FUSDManagement>(admin_addr), E_NOT_AUTHORIZED);
        
        let caps = borrow_global<FUSDManagement>(admin_addr);
        coin::burn(coins, &caps.burn_cap);
    }

    /// Register the coin for an account
    public entry fun register(account: &signer) {
        coin::register<FUSD>(account);
    }
    
    /// Get total supply
    public fun get_supply(): u64 {
        let supply_opt = coin::supply<FUSD>();
        if (std::option::is_some(&supply_opt)) {
            (*std::option::borrow(&supply_opt) as u64)
        } else {
            0
        }
    }

    /// Get balance of account
    public fun balance(addr: address): u64 {
        coin::balance<FUSD>(addr)
    }

    #[test_only]
    public fun init_for_test(admin: &signer) {
        initialize(admin);
    }
}
