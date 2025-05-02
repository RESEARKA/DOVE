// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./DOVEFeeBase.sol";

/**
 * @title DOVE Fee Calculator
 * @dev Handles fee calculation logic for charity fees and early-sell tax
 */
abstract contract DOVEFeeCalculator is DOVEFeeBase {
    /**
     * @dev Calculate charity fee amount for a transfer
     * @param amount Amount of tokens being transferred
     * @return feeAmount Amount to be taken as fee
     */
    function calculateCharityFee(uint256 amount) public pure returns (uint256) {
        return (amount * CHARITY_FEE) / BASIS_POINTS;
    }
    
    /**
     * @dev Calculate early sell tax amount
     * @param amount Amount of tokens being sold
     * @param holder Address selling tokens
     * @param isDexSell Whether this is a sell to a DEX
     * @return taxAmount Amount to be taken as tax
     */
    function calculateEarlySellTax(
        uint256 amount,
        address holder,
        bool isDexSell
    ) public view returns (uint256) {
        // Skip tax if not a DEX sell
        if (!isDexSell) {
            return 0;
        }
        
        // Skip tax calculation for excluded addresses to save gas
        if (_isExcludedFromFee[holder]) {
            return 0;
        }
        
        // Cache storage variables in memory to reduce gas costs
        // This prevents multiple storage reads of the same variables
        bool isTokenLaunched = _isLaunched;
        uint256 launchTimestamp = _launchTimestamp;
        uint256 taxRateDayOne = _taxRateDayOne;
        uint256 taxRateDayTwo = _taxRateDayTwo;
        uint256 taxRateDayThree = _taxRateDayThree;
        
        // Early check - if tax is disabled or token not launched, no tax applies
        if (!_isEarlySellTaxEnabled || !isTokenLaunched) {
            return 0;
        }
        
        // Calculate time elapsed since launch using cached timestamp
        uint256 timeElapsed = block.timestamp - launchTimestamp;
        
        // Determine tax rate based on time elapsed
        uint16 taxRate;
        
        if (timeElapsed < taxRateDayOne) {
            taxRate = TAX_RATE_DAY_1;
        } else if (timeElapsed < taxRateDayOne + taxRateDayTwo) {
            taxRate = TAX_RATE_DAY_2;
        } else if (timeElapsed < taxRateDayOne + taxRateDayTwo + taxRateDayThree) {
            taxRate = TAX_RATE_DAY_3;
        } else {
            // After all time periods, no tax applies
            taxRate = 0;
        }
        
        // Apply tax rate to determine amount
        return (amount * taxRate) / BASIS_POINTS;
    }
    
    /**
     * @dev Check if an address is a known DEX
     * @param addr Address to check
     * @return True if the address is a known DEX
     */
    function isKnownDex(address addr) public view returns (bool) {
        return _isKnownDex[addr];
    }
    
    /**
     * @dev Check if an address is excluded from fees
     * @param addr Address to check
     * @return True if the address is excluded from fees
     */
    function isExcludedFromFee(address addr) public view returns (bool) {
        return _isExcludedFromFee[addr];
    }
}
