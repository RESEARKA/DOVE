# O3 DOVE Token Implementation Advice - 2025-04-30 18:14:26

## Question


I'm implementing a new ERC-20 token called DOVE with the following requirements:

- Token parameters:
  - Name/Symbol: DOVE/DOVE
  - Chain: Base L2 (ERC-20)
  - Total Supply: 100,000,000,000 DOVE (hard-capped)
  - Standards: ERC20Permit, Ownable2Step, Pausable, Burnable
  
- Tax mechanisms:
  - 1% Reflection tax (redistributed instantly to all non-excluded holders)
  - Early-sell tax: 3% (0-24h) → 2% (24-48h) → 1% (48-72h) → 0% (after 72h)
  - maxTx = 0.2% of supply for first 24h → 0.5% afterwards

- Technical stack:
  - Solidity 0.8.24
  - OpenZeppelin v5 libraries
  - Foundry + Hardhat for testing/deployment
  
What's the best way to structure this project, including:
1. Directory structure
2. Smart contract architecture
3. Key files and their relationships
4. Recommended approach for implementing the reflection mechanism
5. Testing strategy for the tax functionality

Please provide specific advice with examples where appropriate.


## Answer

### Recommended Project Structure for DOVE Token

Based on your requirements for the DOVE token on Base L2, here's a comprehensive approach to structuring and implementing your project:

### 1. Directory Structure

```
dove-token/
├── contracts/
│   ├── DOVE.sol                  # Core ERC-20 implementation with reflection
│   ├── libraries/
│   │   └── ReflectionMath.sol    # Reflection calculation library
│   ├── vesting/
│   │   └── VestingWallet.sol     # For team and partner token vesting
│   ├── governance/
│   │   └── CharityMultisig.sol   # 3-of-5 multisig for charity funds
│   └── utils/
│       └── TimeLock.sol          # LP locking mechanism
├── script/
│   ├── Deploy.s.sol              # Foundry deployment script
│   └── SeedLiquidity.s.sol       # LP seeding script
├── test/
│   ├── DOVE.t.sol                # Core token tests
│   ├── Reflection.t.sol          # Reflection-specific tests
│   ├── EarlySellTax.t.sol        # Time-based tax tests
│   ├── MaxTx.t.sol               # Transaction limit tests
│   └── TimeLock.t.sol            # LP locking tests
├── scripts/                      # Hardhat TS scripts
│   ├── deploy/
│   │   └── dove.ts               # Full deployment sequence
│   └── utils/
│       ├── verify.ts             # BaseScan verification
│       └── ask_o3.py             # Security analysis script
├── .env                          # Environment variables (gitignored)
├── .gitignore
├── foundry.toml                  # Foundry configuration
├── hardhat.config.ts             # Hardhat configuration
├── package.json
└── README.md
```

### 2. Smart Contract Architecture

The DOVE token implementation should follow a modular design with clear separation of concerns:

#### Core Token (`DOVE.sol`)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./libraries/ReflectionMath.sol";

contract DOVE is ERC20Permit, Ownable2Step, Pausable, ERC20Burnable {
    using ReflectionMath for uint256;

    // Core state variables
    uint256 private constant TOTAL_SUPPLY = 100_000_000_000 * 10**18;
    uint256 private constant MAX_TX_INITIAL = TOTAL_SUPPLY * 2 / 1000;  // 0.2%
    uint256 private constant MAX_TX_AFTER = TOTAL_SUPPLY * 5 / 1000;    // 0.5%

    // Tax rates (basis points: 100 = 1%)
    uint16 private constant REFLECTION_TAX_BP = 100;  // 1%
    uint16 private constant EARLY_SELL_TAX_24H_BP = 300;  // 3%
    uint16 private constant EARLY_SELL_TAX_48H_BP = 200;  // 2%
    uint16 private constant EARLY_SELL_TAX_72H_BP = 100;  // 1%

    // Reflection tracking
    uint256 private rTotal;
    uint256 private tFeeTotal;
    mapping(address => bool) private isExcludedFromFee;
    mapping(address => uint256) private _firstBuyTimestamp;

    // Launch timestamps
    uint256 public launchTimestamp;
    bool public maxTxLimitEnabled = true;

    // Events
    event ReflectionFeeCollected(uint256 tFee);
    event EarlySellTaxCollected(address indexed seller, uint256 taxAmount);
    event ExcludeFromFee(address indexed account, bool excluded);
    event MaxTxLimitDisabled();

    constructor() ERC20("DOVE", "DOVE") ERC20Permit("DOVE") Ownable() {
        // Initialize reflection
        rTotal = (MAX_UINT256 - (MAX_UINT256 % TOTAL_SUPPLY));
        
        // Mint total supply to deployer
        _mint(msg.sender, TOTAL_SUPPLY);
        
        // Set exclusions
        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(0)] = true;
        isExcludedFromFee[address(this)] = true;
        
        // Start paused, unpause at launch
        _pause();
    }

    // Main transfer override with reflection and early sell tax
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override whenNotPaused {
        // Implementation details...
    }

    // Additional functions...
}
```

#### Reflection Library (`ReflectionMath.sol`)

This library should handle the complex reflection calculations:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library ReflectionMath {
    // Constants
    uint256 private constant MAX_UINT256 = type(uint256).max;

    struct ReflectionValues {
        uint256 rAmount;
        uint256 rTransferAmount;
        uint256 rFee;
        uint256 tTransferAmount;
        uint256 tFee;
    }

    // Core reflection calculation functions
    function getValues(
        uint256 tAmount,
        uint256 currentRate,
        uint16 taxBasisPoints
    ) internal pure returns (ReflectionValues memory values) {
        // Implementation details...
    }

    // Additional helper functions...
}
```

### 3. Key Files and Their Relationships

#### Relationships between Components:

1. **DOVE.sol** → **ReflectionMath.sol**:
   - DOVE contract uses the ReflectionMath library for all reflection-related calculations
   - This separation keeps the core token contract cleaner and more maintainable

2. **Deploy.s.sol** → **DOVE.sol** → **VestingWallet.sol**:
   - Deployment script first deploys DOVE token
   - Then deploys vesting contracts for team, marketing allocations
   - Finally transfers tokens to appropriate vesting contracts

3. **SeedLiquidity.s.sol** → **DOVE.sol** → **TimeLock.sol**:
   - Liquidity script adds tokens to DEX pool
   - Gets LP tokens back and locks them in timelock

### 4. Recommended Approach for Reflection Mechanism

For the reflection mechanism, I recommend a non-iterative approach that's gas-efficient and scales with any number of holders:

#### Non-Iterative Reflection Mechanism

```solidity
// Core concept: use a rate between "reflected" and "standard" tokens
uint256 private constant TOTAL_SUPPLY = 100_000_000_000 * 10**18;
uint256 private _rTotal;    // reflected total (starts very large)
uint256 private _tFeeTotal; // total fees collected

// Token balances are stored in "reflected" form
mapping(address => uint256) private _rOwned;

// Excluded addresses store actual token balance
mapping(address => uint256) private _tOwned;
mapping(address => bool) private _isExcluded;

// Calculate current rate between reflected and actual tokens
function _getCurrentRate() private view returns (uint256) {
    return _rTotal / (TOTAL_SUPPLY - _tFeeTotal);
}

// When transferring tokens
function _tokenTransfer(
    address sender,
    address recipient,
    uint256 amount,
    bool takeFee
) private {
    uint256 rate = _getCurrentRate();
    
    // Calculate values including fees
    ReflectionValues memory values = getValues(amount, rate, takeFee ? REFLECTION_TAX_BP : 0);
    
    // Update balances
    _rOwned[sender] = _rOwned[sender] - values.rAmount;
    _rOwned[recipient] = _rOwned[recipient] + values.rTransferAmount;
    
    // Take fee by reducing rTotal (this automatically redistributes to all holders)
    _rTotal = _rTotal - values.rFee;
    _tFeeTotal = _tFeeTotal + values.tFee;
}
```

The key advantage of this approach is that it doesn't need to iterate through all holders to distribute fees. Instead, it uses a mathematical relationship between "reflected" and "actual" tokens so that when fees are collected, everyone's balance automatically increases proportionally when they convert their reflected balance to actual balance.

### 5. Testing Strategy for Tax Functionality

A comprehensive testing strategy should include:

#### Unit Tests (Using Foundry)

1. **Reflection Tax Tests**:
   ```solidity
   function testReflectionDistribution() public {
       // Setup: Create 5 test accounts with equal balances
       address[5] memory accounts = setupAccounts(1000 ether);
       
       // Action: Account 0 transfers to external address (taxed)
       uint256 transferAmount = 100 ether;
       uint256 expectedFee = transferAmount * 1 / 100; // 1%
       dove.transfer(accounts[0], newUser, transferAmount);
       
       // Assertion: All other accounts should receive reflection
       // Each account should get (expectedFee * their_balance / total_balance_of_receivers)
       for (uint i = 1; i < 5; i++) {
           uint256 expectedReflection = expectedFee * 1000 ether / (4 * 1000 ether);
           assertEq(dove.balanceOf(accounts[i]), 1000 ether + expectedReflection);
       }
   }
   ```

2. **Early Sell Tax Tests**:
   ```solidity
   function testEarlySellTaxDecreases() public {
       // Setup
       address seller = setupAccount(1000 ether);
       address buyer = address(0x999);
       
       // Test tax at 0 hours (3%)
       uint256 transferAmount = 100 ether;
       dove.transfer(seller, buyer, transferAmount);
       assertEq(dove.balanceOf(buyer), transferAmount * 97 / 100);
       
       // Advance time 25 hours
       vm.warp(block.timestamp + 25 hours);
       
       // Test tax at 25 hours (2%)
       dove.transfer(seller, buyer, transferAmount);
       assertEq(dove.balanceOf(buyer), transferAmount * 97 / 100 + transferAmount * 98 / 100);
       
       // Similar tests for 48h→72h→beyond
   }
   ```

3. **Max Transaction Tests**:
   ```solidity
   function testMaxTransactionEnforcement() public {
       // Test: Cannot exceed maxTx during first 24h
       address whale = setupAccount(TOTAL_SUPPLY / 100);
       address recipient = address(0x888);
       
       // Should fail - exceeds 0.2%
       uint256 tooLarge = TOTAL_SUPPLY * 3 / 1000; // 0.3%
       vm.expectRevert("DOVE: Transfer exceeds max transaction amount");
       dove.transfer(whale, recipient, tooLarge);
       
       // Should succeed - under 0.2%
       uint256 underLimit = TOTAL_SUPPLY * 1 / 1000; // 0.1%
       dove.transfer(whale, recipient, underLimit);
       
       // Test: Limit increases after 24h
       // (...)
   }
   ```

#### Fuzz Testing
```solidity
function testFuzz_ReflectionWithRandomTransfers(uint256 amount) public {
    // Bound to reasonable values
    vm.assume(amount > 0.01 ether && amount < 1000 ether);
    
    // Setup accounts
    address sender = setupAccount(10000 ether);
    address recipient = address(0x777);
    
    // Track total supply before
    uint256 totalBefore = dove.totalSupply();
    
    // Execute transfer with reflection
    dove.transfer(sender, recipient, amount);
    
    // Total supply should remain unchanged
    assertEq(dove.totalSupply(), totalBefore);
}
```

#### Integration Tests
Test the entire flow from deployment to launch:

```solidity
function testFullLaunchFlow() public {
    // 1. Deploy token (already done in setUp)
    // 2. Deploy vesting contracts
    VestingWallet teamVesting = new VestingWallet(...);
    
    // 3. Transfer allocations
    dove.transfer(address(teamVesting), 7_500_000_000 * 10**18); // 7.5%
    
    // 4. Add liquidity
    dove.approve(address(router), 10_000_000_000 * 10**18);
    router.addLiquidity(...);
    
    // 5. Lock LP tokens
    // ...
    
    // 6. Unpause trading
    dove.unpause();
    
    // 7. Test trading flow with taxes
    // ...
}
```

### Conclusion

This modular, library-based approach to implementing the DOVE token on Base L2 keeps your code maintainable, secure, and gas-efficient. The non-iterative reflection model in particular will ensure that your token remains functional regardless of the number of holders.

A few additional recommendations:

1. **Gas Optimization**: Implement the reflection math very carefully to minimize gas costs on Base L2
2. **Security First**: Use OpenZeppelin's battle-tested implementations as your foundation
3. **Thorough Testing**: Pay special attention to edge cases in the time-based tax decay
4. **Static Analysis**: Run Slither and other static analyzers regularly during development
5. **Documentation**: Document all public functions with NatSpec comments

Following this structure and implementation approach will result in a secure, efficient DOVE token that meets all your specified requirements.