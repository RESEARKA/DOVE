// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title Reflection
 * @dev Library implementing a non-iterative reflection mechanism for tokens
 * This approach avoids gas-intensive loops by using rate-based calculations
 */
library Reflection {
    struct ReflectionState {
        // Total token supply (fixed amount)
        uint256 totalSupply;
        
        // Total reflection supply (will be much larger than totalSupply)
        uint256 reflectionTotal;
        
        // Total fees collected and reflected back to holders
        uint256 totalFees;
        
        // Current rate between reflection and tokens
        uint256 currentRate;
        
        // Mapping of excluded addresses from reflection (e.g. exchanges, burn address)
        mapping(address => bool) isExcluded;
        
        // Number of excluded accounts
        uint32 excludedCount;
        
        // Total tokens held by excluded accounts
        uint256 tokensExcluded;
        
        // Total reflections owned by excluded accounts
        uint256 reflectionsExcluded;
        
        // Reflection balances for each address
        mapping(address => uint256) reflectionBalance;
        
        // Token balances specifically for excluded addresses
        mapping(address => uint256) tokenBalance;
    }
    
    /**
     * @dev Initializes the reflection state
     * @param state Reflection state to initialize
     * @param initialSupply Initial token supply
     */
    function initialize(ReflectionState storage state, uint256 initialSupply) internal {
        // Set total supply of tokens
        state.totalSupply = initialSupply;
        
        // Reflection total is set to uint256.max - (uint256.max % totalSupply)
        // This ensures that reflection amounts are always divisible by total supply
        state.reflectionTotal = type(uint256).max - (type(uint256).max % initialSupply);
        
        // Initial rate between reflection and tokens
        state.currentRate = state.reflectionTotal / initialSupply;
    }
    
    /**
     * @dev Converts a token amount to reflection amount
     * @param state Reflection state
     * @param tokenAmount Amount of tokens to convert
     * @return reflectionAmount Equivalent amount in reflections
     */
    function tokenToReflection(
        ReflectionState storage state,
        uint256 tokenAmount
    ) internal view returns (uint256) {
        require(tokenAmount <= state.totalSupply, "Amount exceeds total supply");
        return tokenAmount * state.currentRate;
    }
    
    /**
     * @dev Converts a reflection amount to token amount
     * @param state Reflection state
     * @param reflectionAmount Amount of reflections to convert
     * @return tokenAmount Equivalent amount in tokens
     */
    function reflectionToToken(
        ReflectionState storage state,
        uint256 reflectionAmount
    ) internal view returns (uint256) {
        require(reflectionAmount <= state.reflectionTotal, "Amount exceeds total reflection");
        return reflectionAmount / state.currentRate;
    }
    
    /**
     * @dev Returns the token balance of an account
     * @param state Reflection state
     * @param account Address to query
     * @return Token balance
     */
    function balanceOf(
        ReflectionState storage state,
        address account
    ) internal view returns (uint256) {
        if (state.isExcluded[account]) {
            return state.tokenBalance[account];
        }
        return reflectionToToken(state, state.reflectionBalance[account]);
    }
    
    /**
     * @dev Excludes an account from receiving reflections (e.g., exchanges, burn wallet)
     * @param state Reflection state
     * @param account Address to exclude
     */
    function excludeAccount(ReflectionState storage state, address account) internal {
        require(account != address(0), "Cannot exclude zero address");
        require(!state.isExcluded[account], "Account already excluded");
        
        // Calculate token balance based on current reflection balance
        uint256 tokenBalance = 0;
        if (state.reflectionBalance[account] > 0) {
            tokenBalance = reflectionToToken(state, state.reflectionBalance[account]);
            state.tokenBalance[account] = tokenBalance;
            
            // Update exclusion totals
            state.tokensExcluded += tokenBalance;
            state.reflectionsExcluded += state.reflectionBalance[account];
        }
        
        state.isExcluded[account] = true;
        state.excludedCount++;
    }
    
    /**
     * @dev Includes a previously excluded account in reflections
     * @param state Reflection state
     * @param account Address to include
     */
    function includeAccount(ReflectionState storage state, address account) internal {
        require(account != address(0), "Cannot include zero address");
        require(state.isExcluded[account], "Account already included");
        
        // Update exclusion totals if account has a balance
        if (state.tokenBalance[account] > 0) {
            state.tokensExcluded -= state.tokenBalance[account];
            
            // Get current reflection value of tokens
            uint256 reflectionValue = tokenToReflection(state, state.tokenBalance[account]);
            state.reflectionsExcluded -= reflectionValue;
            
            // Update to reflection-based balance
            state.reflectionBalance[account] = reflectionValue;
        }
        
        // Reset token balance and mark as included
        state.tokenBalance[account] = 0;
        state.isExcluded[account] = false;
        state.excludedCount--;
    }
    
    /**
     * @dev Takes a reflection fee from a transaction
     * @param state Reflection state
     * @param fee Fee amount in tokens
     */
    function takeFee(ReflectionState storage state, uint256 fee) internal {
        // Update total fees
        state.totalFees += fee;
        
        // Calculate reflection fee
        uint256 reflectionFee = tokenToReflection(state, fee);
        
        // Update rate to reflect the fee distribution
        state.currentRate = (state.reflectionTotal - reflectionFee) / 
                           (state.totalSupply - fee - state.tokensExcluded);
    }
    
    /**
     * @dev Transfer tokens with potential reflection
     * @param state Reflection state
     * @param sender Sender address
     * @param recipient Recipient address
     * @param amount Amount of tokens to transfer
     * @param feePercent Fee percentage (100 = 1%)
     * @return fee Amount of fee collected
     */
    function transfer(
        ReflectionState storage state,
        address sender,
        address recipient,
        uint256 amount,
        uint16 feePercent
    ) internal returns (uint256) {
        // Calculate fee amount (if any) - preventing overflow by dividing first when possible
        uint256 fee;
        if (feePercent > 0) {
            // For small fee percentages, divide first to prevent overflow
            if (feePercent <= 100) { // 1% or less
                fee = amount / 10000 * feePercent;
            } else {
                // For larger percentages, safeguard the calculation
                fee = amount * feePercent / 10000;
            }
        } else {
            fee = 0;
        }
        
        uint256 transferAmount = amount - fee;
        
        // Cache tokenToReflection values to avoid redundant calculations
        uint256 reflectionAmount = tokenToReflection(state, amount);
        uint256 reflectionTransferAmount = tokenToReflection(state, transferAmount);
        
        // Following checks-effects-interactions pattern to prevent reentrancy
        if (state.isExcluded[sender] && state.isExcluded[recipient]) {
            // Both sender and recipient are excluded
            state.tokenBalance[sender] -= amount;
            state.tokenBalance[recipient] += transferAmount;
        } else if (state.isExcluded[sender]) {
            // Only sender is excluded
            state.tokenBalance[sender] -= amount;
            state.reflectionBalance[recipient] += reflectionTransferAmount;
        } else if (state.isExcluded[recipient]) {
            // Only recipient is excluded
            state.reflectionBalance[sender] -= reflectionAmount;
            state.tokenBalance[recipient] += transferAmount;
        } else {
            // Neither is excluded
            state.reflectionBalance[sender] -= reflectionAmount;
            state.reflectionBalance[recipient] += reflectionTransferAmount;
        }
        
        // Take fee after all balance updates are complete
        if (fee > 0) {
            takeFee(state, fee);
        }
        
        return fee;
    }
}
