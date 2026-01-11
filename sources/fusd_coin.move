module fusd::fusd_coin {
    use std::string;
    use std::signer;
    use aptos_framework::coin::{Self, BurnCapability, FreezeCapability, MintCapability};
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;
    
    /// The FUSD token marker
    struct FUSD has key {}

    /// Storage for authorities to manage the FUSD coin
    struct FUSDManagement has key {
        burn_cap: BurnCapability<FUSD>,
        freeze_cap: FreezeCapability<FUSD>,
        mint_cap: MintCapability<FUSD>,
        mint_events: EventHandle<MintEvent>,
        burn_events: EventHandle<BurnEvent>,
    }

    /// Minting limits per epoch
    struct MintLimits has key {
        max_mint_per_epoch: u64,
        current_epoch_minted: u64,
        epoch_start_time: u64,
        epoch_duration: u64,
    }

    /// Events
    struct MintEvent has drop, store {
        amount: u64,
        recipient: address,
        timestamp: u64,
    }

    struct BurnEvent has drop, store {
        amount: u64,
        timestamp: u64,
    }

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1001;
    const E_MINT_LIMIT_EXCEEDED: u64 = 1002;
    const E_INVALID_AMOUNT: u64 = 1003;
    const E_ZERO_AMOUNT: u64 = 1004;

    /// Constants
    const EPOCH_DURATION: u64 = 86400; // 24 hours
    const MAX_MINT_PER_EPOCH: u64 = 100000000000; // 1000 FUSD per day max

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
            mint_events: account::new_event_handle<MintEvent>(admin),
            burn_events: account::new_event_handle<BurnEvent>(admin),
        });

        move_to(admin, MintLimits {
            max_mint_per_epoch: MAX_MINT_PER_EPOCH,
            current_epoch_minted: 0,
            epoch_start_time: aptos_framework::timestamp::now_seconds(),
            epoch_duration: EPOCH_DURATION,
        });
    }

    /// Mint FUSD tokens with epoch limits
    public fun mint(admin: &signer, amount: u64): aptos_framework::coin::Coin<FUSD> 
    acquires FUSDManagement, MintLimits {
        let admin_addr = signer::address_of(admin);
        assert!(exists<FUSDManagement>(admin_addr), E_NOT_AUTHORIZED);
        assert!(amount > 0, E_ZERO_AMOUNT);
        
        // Check and update mint limits
        let limits = borrow_global_mut<MintLimits>(admin_addr);
        let current_time = aptos_framework::timestamp::now_seconds();
        
        // Reset epoch if needed
        if (current_time >= limits.epoch_start_time + limits.epoch_duration) {
            limits.current_epoch_minted = 0;
            limits.epoch_start_time = current_time;
        };
        
        // Check mint limit
        assert!(
            limits.current_epoch_minted + amount <= limits.max_mint_per_epoch,
            E_MINT_LIMIT_EXCEEDED
        );
        
        limits.current_epoch_minted = limits.current_epoch_minted + amount;
        
        let caps = borrow_global_mut<FUSDManagement>(admin_addr);
        let coins = coin::mint(amount, &caps.mint_cap);
        
        // Emit event
        event::emit_event(&mut caps.mint_events, MintEvent {
            amount,
            recipient: admin_addr,
            timestamp: current_time,
        });
        
        coins
    }

    /// Burn FUSD tokens
    public fun burn(admin: &signer, coins: aptos_framework::coin::Coin<FUSD>) 
    acquires FUSDManagement {
        let admin_addr = signer::address_of(admin);
        assert!(exists<FUSDManagement>(admin_addr), E_NOT_AUTHORIZED);
        
        let amount = coin::value(&coins);
        assert!(amount > 0, E_ZERO_AMOUNT);
        
        let caps = borrow_global_mut<FUSDManagement>(admin_addr);
        coin::burn(coins, &caps.burn_cap);
        
        // Emit event
        event::emit_event(&mut caps.burn_events, BurnEvent {
            amount,
            timestamp: aptos_framework::timestamp::now_seconds(),
        });
    }

    /// System burn (for liquidity pool)
    public fun burn_from_system(coins: aptos_framework::coin::Coin<FUSD>) 
    acquires FUSDManagement {
        let amount = coin::value(&coins);
        assert!(amount > 0, E_ZERO_AMOUNT);
        
        let caps = borrow_global<FUSDManagement>(@fusd);
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

    /// Get remaining mint capacity for current epoch
    public fun get_remaining_mint_capacity(): u64 acquires MintLimits {
        if (exists<MintLimits>(@fusd)) {
            let limits = borrow_global<MintLimits>(@fusd);
            let current_time = aptos_framework::timestamp::now_seconds();
            
            // Check if epoch has reset
            if (current_time >= limits.epoch_start_time + limits.epoch_duration) {
                limits.max_mint_per_epoch
            } else {
                limits.max_mint_per_epoch - limits.current_epoch_minted
            }
        } else {
            0
        }
    }

    /// Update mint limit (Admin only)
    public entry fun set_mint_limit(admin: &signer, new_limit: u64) acquires MintLimits {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_AUTHORIZED);
        assert!(new_limit > 0, E_INVALID_AMOUNT);
        
        let limits = borrow_global_mut<MintLimits>(admin_addr);
        limits.max_mint_per_epoch = new_limit;
    }
    
    #[test_only]
    public fun init_for_test(admin: &signer) {
        initialize(admin);
    }
}
