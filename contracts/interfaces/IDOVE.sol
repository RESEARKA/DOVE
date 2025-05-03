// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DOVE Token Interface
 * @dev Interface for the DOVE token with charity fee and early sell tax mechanics
 */
interface IDOVE is IERC20 {
    /**
     * @dev Returns the charity fee percentage (in basis points)
     * @return Fee percentage (e.g., 50 = 0.5%)
     */
    function getCharityFee() external view returns (uint16);
    
    /**
     * @dev Returns the current charity wallet address
     * @return Address of the charity wallet
     */
    function getCharityWallet() external view returns (address);
    
    /**
     * @dev Returns the timestamp when the token was launched
     * @return Timestamp of launch
     */
    function getLaunchTimestamp() external view returns (uint256);
    
    /**
     * @dev Returns the total amount of charity donations made
     * @return Total amount in token units
     */
    function getTotalCharityDonations() external view returns (uint256);
    
    /**
     * @dev Checks if an address is excluded from fees
     * @param account Address to check
     * @return True if excluded from fees
     */
    function isExcludedFromFee(address account) external view returns (bool);
    
    /**
     * @dev Returns the early sell tax rate for an address
     * @param seller Address to check
     * @return Early sell tax rate (in basis points)
     */
    function getEarlySellTaxFor(address seller) external view returns (uint16);
    
    /**
     * @dev Checks if early sell tax is enabled
     * @return True if early sell tax is enabled
     */
    function isEarlySellTaxEnabled() external view returns (bool);
    
    /**
     * @dev Checks if token has been launched
     * @return True if token is launched
     */
    function isLaunched() external view returns (bool);
    
    /**
     * @dev Returns the maximum allowed transaction amount
     * @return Maximum transaction amount
     */
    function getMaxTransactionAmount() external view returns (uint256);
    
    /**
     * @dev Events emitted by the DOVE token
     */
    event CharityDonation(address indexed from, uint256 amount);
    event EarlySellTaxBurned(address indexed seller, uint256 amount);
    event TokenLaunched(uint256 timestamp);
    event CharityWalletUpdated(address oldWallet, address newWallet);
    event EarlySellTaxDisabled();
    event MaxTransactionLimitDisabled();
}
