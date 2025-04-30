# DOVE Token

DOVE is an ERC-20 token built on Base L2 with reflection and early-sell taxation mechanisms.

## Overview

DOVE implements a set of taxation mechanisms to incentivize long-term holding:
- 1% reflection tax redistributed to all holders
- Declining early-sell tax (3% → 2% → 1% → 0%) over the first 72 hours
- Transaction limits to prevent dumping

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
│   ├── libraries/        # Helper libraries
│   ├── vesting/          # Token vesting contracts
│   ├── governance/       # Multisig and governance
│   └── utils/            # Utility contracts
├── script/               # Foundry deployment scripts
├── test/                 # Tests (Foundry)
├── scripts/              # Hardhat TypeScript scripts
│   ├── deploy/           # Deployment scripts
│   └── utils/            # Helper scripts
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
4. Update `.env` with your private key and API keys

## Testing

```bash
# Run Foundry tests
pnpm test:foundry

# Run with gas reporting
pnpm test:gas

# Run slither security analysis
pnpm slither
```

## Deployment

The deployment process follows these steps:

1. Deploy core token contract:
   ```bash
   pnpm deploy:sepolia  # Test deployment
   pnpm deploy:mainnet  # Production deployment
   ```

2. Verify contracts on BaseScan:
   ```bash
   pnpm verify:sepolia <contract-address>
   pnpm verify:mainnet <contract-address>
   ```

## Security

This project implements several security features:
- Static analysis with Slither
- Gas optimization
- Test coverage with Forge
- Non-iterative reflection mechanism for gas efficiency
- Standard OpenZeppelin contracts as base

## License

MIT
