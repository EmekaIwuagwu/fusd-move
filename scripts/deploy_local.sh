#!/bin/bash

# Local Deployment Script for FUSD

# 1. Initialize Aptos local node (in separate terminal)
# aptos node run-local-testnet --with-faucet

# 2. Create deployment account
aptos init --profile fusd-deployer --network local

# 3. Fund the account
aptos account fund-with-faucet \
  --account fusd-deployer \
  --amount 100000000

# 4. Compile the Move modules
aptos move compile --package-dir .

# 5. Run all tests
aptos move test --package-dir .

# 6. Deploy to local node
aptos move publish \
  --package-dir . \
  --profile fusd-deployer \
  --named-addresses fusd=fusd-deployer

# 7. Initialize the coin
aptos move run \
  --function-id 'fusd-deployer::fusd_coin::initialize' \
  --profile fusd-deployer

echo "FUSD Deployment Complete!"
