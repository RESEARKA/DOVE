# DOVE Token

DOVE is an ERC-20 token built on Base L2 with charity donations and early-sell taxation mechanisms.

## Overview

DOVE implements a set of taxation mechanisms to create social impact while protecting token value:
- 0.5% charity fee directing funds to charitable initiatives
- Declining early-sell tax (3% → 2% → 1% → 0%) over the first 72 hours that gets burned
- Transaction limits to prevent dumping and protect early investors

## Technical Stack

- **Smart Contracts:** Solidity 0.8.24
- **Libraries:** OpenZeppelin v5
- **Development:** Hardhat + Foundry hybrid
- **Testing:** Forge (Foundry) + TypeScript
- **Deployment:** Base L2 Mainnet

## Project Structure

```
dove-token/
├── contracts/            # Solidity contracts
│   ├── DOVE.sol          # Core ERC-20 token implementation
│   ├── interfaces/       # Contract interfaces
│   └── utils/            # Utility contracts
├── scripts/              # Hardhat TypeScript scripts
│   ├── deploy/           # Deployment scripts
│   └── utils/            # Helper scripts
├── test/                 # Tests (Foundry and TypeScript)
```

## Development Setup

1. Clone the repository
2. Install dependencies:
   ```bash
   pnpm install
   ```
3. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```
4. Update `.env` with your private key, API keys, and charity wallet address

## Testing

```bash
# Run Foundry tests
forge test

# Run TypeScript tests
pnpm test

# Run with gas reporting
forge test --gas-report

# Run slither security analysis
slither .
```

## Deployment Process

Following the DOVE Developer Guidelines, the deployment process consists of these steps:

1. Compile & test the contracts:
   ```bash
   forge test
   ```

2. Deploy the DOVE token specifying the charity wallet:
   ```bash
   pnpm hardhat run scripts/deploy/dove.ts --network base
   ```

3. Verify the contract on BaseScan:
   ```bash
   pnpm hardhat verify <DOVE_ADDRESS> <CHARITY_WALLET> --network base
   ```

4. Transfer ownership to the multisig (handled automatically in the deployment script).

5. Seed LP (1.67 ETH + 10B DOVE):
   ```bash
   # First set the DOVE_ADDRESS and DEX_ROUTER_ADDRESS environment variables
   export DOVE_ADDRESS=0x...
   export DEX_ROUTER_ADDRESS=0x...
   
   # Then run the seeding script
   pnpm hardhat run scripts/deploy/seedLp.ts --network base
   ```

6. Lock LP NFT using UNCX locker (to be executed manually).

7. Announce contract & lock links on socials.

## Key Features

### Charity Fee (0.5%)
Every transaction contributes 0.5% to the designated charity wallet, allowing DOVE to make a meaningful social impact. With $1M in daily trading volume, approximately $5,000 would be directed to charity every day.

### Early-Sell Tax
To discourage pump-and-dump behaviors, sales to DEX addresses incur a declining tax:
- 3% for the first 24 hours after launch
- 2% for hours 24-48
- 1% for hours 48-72
- 0% afterwards

Early-sell taxes are burned, reducing the total supply over time.

### Transaction Limits
- 0.2% of total supply per transaction for the first 24 hours
- 0.5% of total supply per transaction after 24 hours
- Excludable addresses for contracts and whitelisted wallets

## Security

This project implements several security features:
- Static analysis with Slither
- Gas optimization throughout the codebase
- Comprehensive test coverage
- Secure fee handling mechanisms
- Standard OpenZeppelin contracts for core functionality

## License

MIT
