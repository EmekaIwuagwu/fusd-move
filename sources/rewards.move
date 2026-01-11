module fusd::rewards {
    use std::signer;
    use std::vector;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;
    use fusd::fusd_coin::FUSD;

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 6001;
    const E_INVALID_LOCK_PERIOD: u64 = 6002;
    const E_STAKE_NOT_FOUND: u64 = 6003;
    const E_LOCK_PERIOD_ACTIVE: u64 = 6004;
    const E_INSUFFICIENT_STAKE: u64 = 6005;
    const E_TOO_MANY_POSITIONS: u64 = 6006;
    const E_STAKE_TOO_SMALL: u64 = 6007;
    const E_REWARD_OVERFLOW: u64 = 6008;
    const E_ZERO_AMOUNT: u64 = 6009;

    /// Lock period constants (in seconds)
    const LOCK_30_DAYS: u64 = 2592000;
    const LOCK_90_DAYS: u64 = 7776000;
    const LOCK_365_DAYS: u64 = 31536000;

    /// Reward multipliers (basis points)
    const MULTIPLIER_30_DAYS: u64 = 500;   // +5%
    const MULTIPLIER_90_DAYS: u64 = 1500;  // +15%
    const MULTIPLIER_365_DAYS: u64 = 3000; // +30%

    /// Base APY (basis points)
    const BASE_APY: u64 = 1500; // 15%

    /// Limits
    const MAX_POSITIONS_PER_USER: u64 = 100;
    const MIN_STAKE_AMOUNT: u64 = 100000000; // 1 FUSD minimum

    /// Events
    struct StakeEvent has drop, store {
        user: address,
        amount: u64,
        lock_period: u64,
        timestamp: u64,
    }

    struct UnstakeEvent has drop, store {
        user: address,
        amount: u64,
        rewards: u64,
        timestamp: u64,
    }

    /// Staking position
    struct StakingPosition has store {
        amount: u64,
        stake_timestamp: u64,
        lock_period: u64,
        reward_multiplier: u64,
    }

    /// User staking state
    struct UserStakes has key {
        positions: vector<StakingPosition>,
        total_staked: u64,
    }

    /// Global rewards pool
    struct RewardsPool has key {
        fusd_reserves: Coin<FUSD>,
        total_distributed: u64,
        stake_events: EventHandle<StakeEvent>,
        unstake_events: EventHandle<UnstakeEvent>,
    }

    /// Initialize rewards pool
    public entry fun initialize(admin: &signer) {
        if (!exists<RewardsPool>(signer::address_of(admin))) {
            move_to(admin, RewardsPool {
                fusd_reserves: coin::zero<FUSD>(),
                total_distributed: 0,
                stake_events: account::new_event_handle<StakeEvent>(admin),
                unstake_events: account::new_event_handle<UnstakeEvent>(admin),
            });
        }
    }

    /// Stake FUSD tokens with validation
    public entry fun stake(user: &signer, amount: u64, lock_period: u64) acquires UserStakes, RewardsPool {
        let user_addr = signer::address_of(user);
        
        assert!(amount >= MIN_STAKE_AMOUNT, E_STAKE_TOO_SMALL);
        
        let multiplier = get_multiplier(lock_period);
        assert!(multiplier > 0, E_INVALID_LOCK_PERIOD);
        
        // Withdraw coins first
        let coins = coin::withdraw<FUSD>(user, amount);
        
        if (!exists<UserStakes>(user_addr)) {
            move_to(user, UserStakes {
                positions: vector::empty<StakingPosition>(),
                total_staked: 0,
            });
        };

        let stakes = borrow_global_mut<UserStakes>(user_addr);
        
        // Check position limit
        assert!(
            vector::length(&stakes.positions) < MAX_POSITIONS_PER_USER,
            E_TOO_MANY_POSITIONS
        );
        
        // Update state BEFORE external call
        vector::push_back(&mut stakes.positions, StakingPosition {
            amount,
            stake_timestamp: timestamp::now_seconds(),
            lock_period,
            reward_multiplier: multiplier,
        });
        stakes.total_staked = stakes.total_staked + amount;
        
        // External call LAST
        coin::deposit(@fusd, coins);
        
        // Emit event
        if (exists<RewardsPool>(@fusd)) {
            let pool = borrow_global_mut<RewardsPool>(@fusd);
            event::emit_event(&mut pool.stake_events, StakeEvent {
                user: user_addr,
                amount,
                lock_period,
                timestamp: timestamp::now_seconds(),
            });
        }
    }

    /// Unstake FUSD tokens - FIXED: Reentrancy protection
    public entry fun unstake(user: &signer, position_index: u64) acquires UserStakes, RewardsPool {
        let user_addr = signer::address_of(user);
        assert!(exists<UserStakes>(user_addr), E_STAKE_NOT_FOUND);

        let stakes = borrow_global_mut<UserStakes>(user_addr);
        assert!(position_index < vector::length(&stakes.positions), E_STAKE_NOT_FOUND);

        let position = vector::borrow(&stakes.positions, position_index);
        let current_time = timestamp::now_seconds();
        
        // Check lock period
        assert!(
            current_time >= position.stake_timestamp + position.lock_period,
            E_LOCK_PERIOD_ACTIVE
        );

        // Remove position and get values
        let StakingPosition { amount, stake_timestamp, lock_period: _, reward_multiplier } = 
            vector::remove(&mut stakes.positions, position_index);

        // Calculate rewards with overflow protection
        let rewards = calculate_rewards_safe(amount, stake_timestamp, current_time, reward_multiplier);
        let total_return = amount + rewards;

        // UPDATE STATE FIRST (reentrancy protection)
        stakes.total_staked = if (stakes.total_staked >= amount) {
            stakes.total_staked - amount
        } else {
            0
        };

        // Process payout
        if (exists<RewardsPool>(@fusd)) {
            let pool = borrow_global_mut<RewardsPool>(@fusd);
            let available = coin::value(&pool.fusd_reserves);
            
            let actual_payout = 0u64;
            let actual_rewards = 0u64;
            
            if (available >= total_return) {
                let payout = coin::extract(&mut pool.fusd_reserves, total_return);
                actual_payout = total_return;
                actual_rewards = rewards;
                
                // Update state BEFORE external call
                pool.total_distributed = pool.total_distributed + rewards;
                
                // External call LAST
                coin::deposit(user_addr, payout);
            } else if (available >= amount) {
                let payout = coin::extract(&mut pool.fusd_reserves, amount);
                actual_payout = amount;
                actual_rewards = 0;
                
                // External call LAST
                coin::deposit(user_addr, payout);
            };
            
            // Emit event
            event::emit_event(&mut pool.unstake_events, UnstakeEvent {
                user: user_addr,
                amount,
                rewards: actual_rewards,
                timestamp: current_time,
            });
        }
    }

    /// Calculate rewards with overflow protection
    fun calculate_rewards_safe(amount: u64, start_time: u64, end_time: u64, multiplier: u64): u64 {
        let duration = end_time - start_time;
        let seconds_per_year: u128 = 31536000;
        
        // Calculate base reward
        let base_calc = ((amount as u128) * (BASE_APY as u128) * (duration as u128)) / 
                       (seconds_per_year * 10000);
        
        // Calculate bonus reward
        let bonus_calc = ((amount as u128) * (multiplier as u128) * (duration as u128)) / 
                        (seconds_per_year * 10000);
        
        let total_reward = base_calc + bonus_calc;
        
        // Check for overflow before casting to u64
        assert!(total_reward <= (18446744073709551615 as u128), E_REWARD_OVERFLOW);
        
        (total_reward as u64)
    }

    /// Get reward multiplier based on lock period
    fun get_multiplier(lock_period: u64): u64 {
        if (lock_period >= LOCK_365_DAYS) {
            MULTIPLIER_365_DAYS
        } else if (lock_period >= LOCK_90_DAYS) {
            MULTIPLIER_90_DAYS
        } else if (lock_period >= LOCK_30_DAYS) {
            MULTIPLIER_30_DAYS
        } else {
            0
        }
    }

    /// Fund rewards pool (Admin only)
    public entry fun fund_rewards_pool(admin: &signer, amount: u64) acquires RewardsPool {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @fusd, E_NOT_AUTHORIZED);
        assert!(amount > 0, E_ZERO_AMOUNT);
        
        let coins = coin::withdraw<FUSD>(admin, amount);
        
        if (!exists<RewardsPool>(admin_addr)) {
            initialize(admin);
        };
        
        let pool = borrow_global_mut<RewardsPool>(admin_addr);
        coin::merge(&mut pool.fusd_reserves, coins);
    }

    /// Get user's total staked amount
    public fun get_total_staked(user: address): u64 acquires UserStakes {
        if (exists<UserStakes>(user)) {
            borrow_global<UserStakes>(user).total_staked
        } else {
            0
        }
    }

    /// Get number of staking positions for a user
    public fun get_position_count(user: address): u64 acquires UserStakes {
        if (exists<UserStakes>(user)) {
            vector::length(&borrow_global<UserStakes>(user).positions)
        } else {
            0
        }
    }

    /// Get rewards pool balance
    public fun get_pool_balance(): u64 acquires RewardsPool {
        if (exists<RewardsPool>(@fusd)) {
            coin::value(&borrow_global<RewardsPool>(@fusd).fusd_reserves)
        } else {
            0
        }
    }
}
