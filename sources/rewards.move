module fusd::rewards {
    use std::signer;
    use std::vector;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use fusd::fusd_coin::FUSD;

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_INVALID_LOCK_PERIOD: u64 = 2;
    const E_STAKE_NOT_FOUND: u64 = 3;
    const E_LOCK_PERIOD_ACTIVE: u64 = 4;
    const E_INSUFFICIENT_STAKE: u64 = 5;

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
    }

    /// Initialize rewards pool
    public entry fun initialize(admin: &signer) {
        if (!exists<RewardsPool>(signer::address_of(admin))) {
            move_to(admin, RewardsPool {
                fusd_reserves: coin::zero<FUSD>(),
                total_distributed: 0,
            });
        }
    }

    /// Stake FUSD tokens
    public entry fun stake(user: &signer, amount: u64, lock_period: u64) acquires UserStakes {
        let user_addr = signer::address_of(user);
        
        let multiplier = get_multiplier(lock_period);
        assert!(multiplier > 0, E_INVALID_LOCK_PERIOD);
        
        let coins = coin::withdraw<FUSD>(user, amount);
        coin::deposit(@fusd, coins);

        if (!exists<UserStakes>(user_addr)) {
            move_to(user, UserStakes {
                positions: vector::empty<StakingPosition>(),
                total_staked: 0,
            });
        };

        let stakes = borrow_global_mut<UserStakes>(user_addr);
        vector::push_back(&mut stakes.positions, StakingPosition {
            amount,
            stake_timestamp: timestamp::now_seconds(),
            lock_period,
            reward_multiplier: multiplier,
        });
        stakes.total_staked = stakes.total_staked + amount;
    }

    /// Unstake FUSD tokens
    public entry fun unstake(user: &signer, position_index: u64) acquires UserStakes, RewardsPool {
        let user_addr = signer::address_of(user);
        assert!(exists<UserStakes>(user_addr), E_STAKE_NOT_FOUND);

        let stakes = borrow_global_mut<UserStakes>(user_addr);
        assert!(position_index < vector::length(&stakes.positions), E_STAKE_NOT_FOUND);

        let position = vector::borrow(&stakes.positions, position_index);
        let current_time = timestamp::now_seconds();
        assert!(
            current_time >= position.stake_timestamp + position.lock_period,
            E_LOCK_PERIOD_ACTIVE
        );

        let StakingPosition { amount, stake_timestamp, lock_period: _, reward_multiplier } = 
            vector::remove(&mut stakes.positions, position_index);

        let rewards = calculate_rewards(amount, stake_timestamp, current_time, reward_multiplier);
        let total_return = amount + rewards;

        stakes.total_staked = if (stakes.total_staked >= amount) {
            stakes.total_staked - amount
        } else {
            0
        };

        if (exists<RewardsPool>(@fusd)) {
            let pool = borrow_global_mut<RewardsPool>(@fusd);
            let available = coin::value(&pool.fusd_reserves);
            
            if (available >= total_return) {
                let payout = coin::extract(&mut pool.fusd_reserves, total_return);
                coin::deposit(user_addr, payout);
                pool.total_distributed = pool.total_distributed + rewards;
            } else if (available >= amount) {
                let payout = coin::extract(&mut pool.fusd_reserves, amount);
                coin::deposit(user_addr, payout);
            }
        }
    }

    /// Calculate rewards for a staking position
    fun calculate_rewards(amount: u64, start_time: u64, end_time: u64, multiplier: u64): u64 {
        let duration = end_time - start_time;
        let seconds_per_year: u64 = 31536000;
        
        let base_reward = ((amount as u128) * (BASE_APY as u128) * (duration as u128)) / 
                         ((seconds_per_year as u128) * 10000);
        
        let bonus_reward = ((amount as u128) * (multiplier as u128) * (duration as u128)) / 
                          ((seconds_per_year as u128) * 10000);
        
        ((base_reward + bonus_reward) as u64)
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
}
