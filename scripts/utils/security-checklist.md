# DOVE Token Security Checklist

This checklist must be completed before mainnet deployment.

## Static Analysis

- [ ] Run Slither on all contracts: `slither .`
- [ ] Resolve all high and medium severity issues
- [ ] Document any false positives or accepted low severity issues

## Testing Coverage

- [ ] Unit tests cover all core functionality
- [ ] Gas snapshots recorded and reviewed
- [ ] Fuzz testing for edge cases (especially for reflection math)
- [ ] Integration tests for full deployment workflow

## Security Review

- [ ] ReentrancyGuard used where needed
- [ ] Verify no unchecked external calls
- [ ] Check for integer overflow/underflow in reflection math
- [ ] Validate maxTx limits calculation
- [ ] Verify early-sell tax decay functionality
- [ ] Confirm events are emitted for all state changes

## Ownership & Access Control

- [ ] Verify Ownable2Step functionality
- [ ] Confirm pausable functions are properly protected
- [ ] Test owner functions with non-owner accounts (should revert)
- [ ] Plan multisig deployment and ownership transfer

## Deployment

- [ ] Verify contract on BaseScan
- [ ] Confirm total supply matches specifications
- [ ] Lock liquidity for specified timeframe
- [ ] Transfer ownership to multisig
- [ ] Verify all contract parameters (taxes, limits, etc.)

## Circuit Breakers

- [ ] Test pause/unpause functionality
- [ ] Verify ability to disable early-sell tax if needed
- [ ] Confirm ability to disable maxTx limits after launch period

## Documentation

- [ ] All public/external functions have NatSpec documentation
- [ ] Architecture diagram updated
- [ ] Deployment addresses recorded
