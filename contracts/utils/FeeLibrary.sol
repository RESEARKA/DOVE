// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title DOVE Fee Library
 * @dev Library containing fee calculation functions for the DOVE token
 * This centralizes all fee calculations to ensure consistency across the system
 */
library FeeLibrary {
    // ================ Constants ================
    
    // Basis points (100% = 10000 basis points)
    uint16 internal constant BASIS_POINTS = 10000;
    
    // Charity fee: 0.5% of transactions sent to charity wallet
    uint16 internal constant CHARITY_FEE = 50; // 50 = 0.50%
    
    // Early sell tax rates (in basis points)
    uint16 internal constant TAX_RATE_DAY_1 = 500; // 5.00% (500 basis points)
    uint16 internal constant TAX_RATE_DAY_2 = 300; // 3.00% (300 basis points)
    uint16 internal constant TAX_RATE_DAY_3 = 100; // 1.00% (100 basis points)
    
    // Time periods for early sell tax
    uint256 internal constant PERIOD_DAY_1 = 1 days;
    uint256 internal constant PERIOD_DAY_2 = 2 days;
    uint256 internal constant PERIOD_DAY_3 = 3 days;
    
    /**
     * @dev Calculate the charity fee amount for a transfer
     * @param amount Amount being transferred
     * @return feeAmount The charity fee amount
     */
    function calculateCharityFee(uint256 amount) internal pure returns (uint256 feeAmount) {
        // Gas-optimized calculation with single division operation
        return amount * CHARITY_FEE / BASIS_POINTS;
    }
    
    /**
     * @dev Get the current charity fee percentage
     * @return The charity fee in basis points
     */
    function getCharityFeePercentage() internal pure returns (uint16) {
        return CHARITY_FEE;
    }
    
    /**
     * @dev Calculate the early sell tax amount for a transfer
     * @param amount Amount being transferred
     * @param timeSinceLaunch Time elapsed since token launch
     * @return taxAmount The early sell tax amount
     */
    function calculateEarlySellTax(
        uint256 amount, 
        uint256 timeSinceLaunch
    ) internal pure returns (uint256 taxAmount) {
        // Get the appropriate tax rate and calculate in a single operation
        uint16 taxRate = getEarlySellTaxRate(timeSinceLaunch);
        return amount * taxRate / BASIS_POINTS;
    }
    
    /**
     * @dev Get the current early sell tax rate based on time elapsed since launch
     * @param timeSinceLaunch Time elapsed since token launch
     * @return taxRate The early sell tax rate in basis points
     */
    function getEarlySellTaxRate(uint256 timeSinceLaunch) internal pure returns (uint16) {
        if (timeSinceLaunch < PERIOD_DAY_1) {
            return TAX_RATE_DAY_1;
        } else if (timeSinceLaunch < PERIOD_DAY_2) {
            return TAX_RATE_DAY_2;
        } else if (timeSinceLaunch < PERIOD_DAY_3) {
            return TAX_RATE_DAY_3;
        } else {
            return 0;
        }
    }
    
    /**
     * @dev Calculate both charity fee and early sell tax for a transfer
     * @param amount Amount being transferred
     * @param timeSinceLaunch Time elapsed since token launch
     * @param isEarlySellTaxApplicable Whether early sell tax applies to this transfer
     * @param isEarlySellTaxEnabled Whether early sell tax is enabled globally
     * @return charityFee The charity fee amount
     * @return sellTax The early sell tax amount
     * @return totalFee The total fee amount (charity fee + sell tax)
     * @return netAmount The net amount after fees
     */
    function calculateAllFees(
        uint256 amount,
        uint256 timeSinceLaunch,
        bool isEarlySellTaxApplicable,
        bool isEarlySellTaxEnabled
    ) internal pure returns (
        uint256 charityFee,
        uint256 sellTax,
        uint256 totalFee,
        uint256 netAmount
    ) {
        // Calculate charity fee (cached for gas optimization)
        charityFee = amount * CHARITY_FEE / BASIS_POINTS;
        
        // Calculate early sell tax if applicable (cached for gas optimization)
        sellTax = 0;
        if (isEarlySellTaxApplicable && isEarlySellTaxEnabled) {
            uint16 taxRate = getEarlySellTaxRate(timeSinceLaunch);
            sellTax = amount * taxRate / BASIS_POINTS;
        }
        
        // Calculate total fee and net amount (avoided repeated calculations)
        totalFee = charityFee + sellTax;
        netAmount = amount - totalFee;
        
        return (charityFee, sellTax, totalFee, netAmount);
    }
}
