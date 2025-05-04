#!/bin/bash
# Script to analyze DOVE contract files with o3 tool

O3_TOOL_PATH="/Users/dom12/Desktop/Business/o3 Tool"
DOVE_CONTRACTS_PATH="/Users/dom12/Desktop/Business/DOVE/contracts"

echo "======================================================================"
echo "Starting DOVE Smart Contract Security Analysis"
echo "======================================================================"

# Analyze main token contract
echo "\n[1/5] Analyzing DOVE.sol..."
python3 "$O3_TOOL_PATH/o3_analyzer.py" analyze "$DOVE_CONTRACTS_PATH/token/DOVE.sol"

# Analyze fee library
echo "\n[2/5] Analyzing FeeLibrary.sol..."
python3 "$O3_TOOL_PATH/o3_analyzer.py" analyze "$DOVE_CONTRACTS_PATH/utils/FeeLibrary.sol"

# Analyze admin contract
echo "\n[3/5] Analyzing DOVEAdmin.sol..."
python3 "$O3_TOOL_PATH/o3_analyzer.py" analyze "$DOVE_CONTRACTS_PATH/admin/DOVEAdmin.sol"

# Analyze governance contract
echo "\n[4/5] Analyzing DOVEGovernance.sol..."
python3 "$O3_TOOL_PATH/o3_analyzer.py" analyze "$DOVE_CONTRACTS_PATH/admin/DOVEGovernance.sol"

# Focus specifically on the tiny transfer fix
echo "\n[5/5] Security check on tiny transfer fix..."
python3 "$O3_TOOL_PATH/o3_analyzer.py" ask "Analyze this code snippet for security vulnerabilities:

```solidity
// Handle tiny transfers to prevent dust accumulation due to integer division
// For the charity fee of 0.5%, any amount less than 200 will result in 0 fee
if (amount < 200) {
    // Transfer without applying fees for tiny amounts
    super._transfer(sender, recipient, amount);
    return;
}
```

Is this implementation secure? Does it properly prevent dust accumulation? Are there any edge cases?"

echo "\n======================================================================"
echo "Analysis complete"
echo "======================================================================" 
