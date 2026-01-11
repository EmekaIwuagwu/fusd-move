module fusd::events {
    friend fusd::rebalancing;

    /// Event emitted when supply expands
    struct RebalanceExpansion has drop, store {
        old_price: u64,
        new_supply: u64,
        amount_minted: u64,
        timestamp: u64,
    }

    /// Event emitted when supply contracts
    struct RebalanceContraction has drop, store {
        old_price: u64,
        new_supply: u64,
        amount_burned: u64,
        timestamp: u64,
    }

    public(friend) fun new_rebalance_expansion(
        old_price: u64,
        new_supply: u64,
        amount_minted: u64,
        timestamp: u64,
    ): RebalanceExpansion {
        RebalanceExpansion {
            old_price,
            new_supply,
            amount_minted,
            timestamp,
        }
    }

    public(friend) fun new_rebalance_contraction(
        old_price: u64,
        new_supply: u64,
        amount_burned: u64,
        timestamp: u64,
    ): RebalanceContraction {
        RebalanceContraction {
            old_price,
            new_supply,
            amount_burned,
            timestamp,
        }
    }
}
