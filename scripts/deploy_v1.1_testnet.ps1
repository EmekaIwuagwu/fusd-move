# FUSD v1.1.0 Testnet Deployment Script
# Address: 0x2791c639877af206489abee02270c597aa6aea0e3c896b72cc99bb4832ca37e7

$ADDRESS = "0x2791c639877af206489abee02270c597aa6aea0e3c896b72cc99bb4832ca37e7"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FUSD v1.1.0 Testnet Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check balance
Write-Host "[1/7] Checking account balance..." -ForegroundColor Yellow
.\bin\aptos.exe account balance --account $ADDRESS --url https://api.testnet.aptoslabs.com

Write-Host ""
Write-Host "Press any key to continue with deployment..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Step 2: Compile
Write-Host ""
Write-Host "[2/7] Compiling contracts..." -ForegroundColor Yellow
.\bin\aptos.exe move compile

# Step 3: Publish
Write-Host ""
Write-Host "[3/7] Publishing to testnet..." -ForegroundColor Yellow
.\bin\aptos.exe move publish --profile fusd-v1.1-testnet --assume-yes

# Step 4: Initialize FUSD Coin
Write-Host ""
Write-Host "[4/7] Initializing FUSD Coin..." -ForegroundColor Yellow
.\bin\aptos.exe move run `
  --function-id "${ADDRESS}::fusd_coin::initialize" `
  --profile fusd-v1.1-testnet `
  --assume-yes

# Step 5: Initialize Governance
Write-Host ""
Write-Host "[5/7] Initializing Governance..." -ForegroundColor Yellow
.\bin\aptos.exe move run `
  --function-id "${ADDRESS}::governance::initialize" `
  --args address:$ADDRESS address:$ADDRESS `
  --profile fusd-v1.1-testnet `
  --assume-yes

# Step 6: Initialize Oracle
Write-Host ""
Write-Host "[6/7] Initializing Oracle..." -ForegroundColor Yellow
.\bin\aptos.exe move run `
  --function-id "${ADDRESS}::oracle_integration::initialize" `
  --profile fusd-v1.1-testnet `
  --assume-yes

# Step 7: Initialize Rebalancing Events
Write-Host ""
Write-Host "[7/7] Initializing Rebalancing Events..." -ForegroundColor Yellow
.\bin\aptos.exe move run `
  --function-id "${ADDRESS}::rebalancing::initialize_events" `
  --profile fusd-v1.1-testnet `
  --assume-yes

# Step 8: Initialize Liquidity Pool
Write-Host ""
Write-Host "[8/9] Initializing Liquidity Pool..." -ForegroundColor Yellow
.\bin\aptos.exe move run `
  --function-id "${ADDRESS}::liquidity_pool::initialize" `
  --profile fusd-v1.1-testnet `
  --assume-yes

# Step 9: Initialize Gas Abstraction
Write-Host ""
Write-Host "[9/9] Initializing Gas Abstraction..." -ForegroundColor Yellow
.\bin\aptos.exe move run `
  --function-id "${ADDRESS}::gas_abstraction::initialize" `
  --args address:$ADDRESS `
  --profile fusd-v1.1-testnet `
  --assume-yes

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Contract Address: $ADDRESS" -ForegroundColor Cyan
Write-Host "Explorer: https://explorer.aptoslabs.com/account/$ADDRESS?network=testnet" -ForegroundColor Cyan
Write-Host ""
