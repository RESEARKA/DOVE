// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title FeeCalculator
 * @dev Library for calculating DOVE fees and taxes
 */
library FeeCalculator {
    // Basis points (100% = 10000 basis points)
    uint16 internal constant BASIS_POINTS = 10000;
    
    // Charity fee: 0.5% of transactions sent to charity wallet
    uint16 internal constant CHARITY_FEE = 50; // 50 = 0.50%
    
    // Early sell tax rates (in basis points)
    uint16 internal constant TAX_RATE_DAY_1 = 500; // 5.00% (500 basis points)
    uint16 internal constant TAX_RATE_DAY_2 = 300; // 3.00% (300 basis points)
    uint16 internal constant TAX_RATE_DAY_3 = 100; // 1.00% (100 basis points)
    
    /**
     * @dev Calculate charity fee amount for a transfer
     * @param amount Amount of tokens being transferred
     * @return feeAmount Amount to be taken as fee
     */
    function calculateCharityFee(uint256 amount) internal pure returns (uint256) {
        return (amount * CHARITY_FEE) / BASIS_POINTS;
    }
    
    /**
     * @dev Calculate early sell tax amount based on time elapsed since launch
     * @param amount Amount being sold
     * @param timeElapsed Time elapsed since token launch
     * @param taxRateDayOne Duration of day 1 tax rate period
     * @param taxRateDayTwo Duration of day 2 tax rate period
     * @param taxRateDayThree Duration of day 3 tax rate period
     * @return Tax amount to be taken
     */
    function calculateEarlySellTaxByTime(
        uint256 amount,
        uint256 timeElapsed,
        uint256 taxRateDayOne,
        uint256 taxRateDayTwo,
        uint256 taxRateDayThree
    ) internal pure returns (uint256) {
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
     * @dev Get tax rate based on time elapsed since launch
     * @param timeElapsed Time elapsed since token launch
     * @param taxRateDayOne Duration of day 1 tax rate period
     * @param taxRateDayTwo Duration of day 2 tax rate period
     * @param taxRateDayThree Duration of day 3 tax rate period
     * @return Tax rate in basis points
     */
    function getEarlySellTaxRate(
        uint256 timeElapsed,
        uint256 taxRateDayOne,
        uint256 taxRateDayTwo,
        uint256 taxRateDayThree
    ) internal pure returns (uint16) {
        if (timeElapsed < taxRateDayOne) {
            return TAX_RATE_DAY_1;
        } else if (timeElapsed < taxRateDayOne + taxRateDayTwo) {
            return TAX_RATE_DAY_2;
        } else if (timeElapsed < taxRateDayOne + taxRateDayTwo + taxRateDayThree) {
            return TAX_RATE_DAY_3;
        } else {
            return 0;
        }
    }
}
