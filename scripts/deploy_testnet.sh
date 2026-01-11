#!/bin/bash

# FUSD Testnet Deployment Script

# Deployer Address: 0xb1899c39c9b05fd6b25b7b8329a355f06186d80d414578ec752135ade379a5a7
# Ensure this account is funded via Faucet before running!

echo "Deploying FUSD to Testnet..."

# 1. Compile (using address in Move.toml)
aptos move compile

# 2. Publish
aptos move publish --profile fusd-testnet

# 3. Initialize Coin
aptos move run \
  --function-id '0xb1899c39c9b05fd6b25b7b8329a355f06186d80d414578ec752135ade379a5a7::fusd_coin::initialize' \
  --profile fusd-testnet

# 4. Initialize Governance
aptos move run \
  --function-id '0xb1899c39c9b05fd6b25b7b8329a355f06186d80d414578ec752135ade379a5a7::governance::initialize' \
  --args address:0xb1899c39c9b05fd6b25b7b8329a355f06186d80d414578ec752135ade379a5a7 address:0xb1899c39c9b05fd6b25b7b8329a355f06186d80d414578ec752135ade379a5a7 \
  --profile fusd-testnet

# 5. Initialize Other Modules
aptos move run --function-id '0xb1899c39c9b05fd6b25b7b8329a355f06186d80d414578ec752135ade379a5a7::oracle_integration::initialize' --profile fusd-testnet
aptos move run --function-id '0xb1899c39c9b05fd6b25b7b8329a355f06186d80d414578ec752135ade379a5a7::rebalancing::initialize_events' --profile fusd-testnet
aptos move run --function-id '0xb1899c39c9b05fd6b25b7b8329a355f06186d80d414578ec752135ade379a5a7::gas_abstraction::initialize' --args address:0xb1899c39c9b05fd6b25b7b8329a355f06186d80d414578ec752135ade379a5a7 --profile fusd-testnet

echo "Deployment Complete!"
