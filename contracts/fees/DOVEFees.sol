// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./DOVEFeeController.sol";
import "../interfaces/IDOVEFees.sol";

/**
 * @title DOVE Fee Management
 * @dev Implementation of fee mechanisms for DOVE token (charity fee and early-sell tax)
 * This contract integrates all fee-related modules into a cohesive system
 */
contract DOVEFees is DOVEFeeController, IDOVEFees {
    // Multi-signature role management
    mapping(bytes32 => mapping(address => bool)) private _roleChangeApprovals;
    mapping(bytes32 => uint256) private _roleChangeApprovalCounts;
    uint256 private _requiredRoleChangeApprovals = 2; // Default: 2 admins required
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor initializes the fee manager with charity wallet
     * @param charityWallet Address to receive charity fees
     */
    constructor(address charityWallet) DOVEFeeBase(charityWallet) {}
    
    // ================ External View Functions ================
    
    /**
     * @dev Get the charity wallet address
     * @return Charity wallet address
     */
    function getCharityWallet() external view override returns (address) {
        return _charityWallet;
    }
    
    /**
     * @dev Get the token address
     * @return Token contract address
     */
    function getTokenAddress() external view override returns (address) {
        return _tokenAddress;
    }
    
    /**
     * @dev Get the charity fee percentage (in basis points)
     * @return Charity fee in basis points
     */
    function getCharityFee() external pure override returns (uint16) {
        return CHARITY_FEE;
    }
    
    /**
     * @dev Get the launch timestamp
     * @return Launch timestamp, 0 if not launched
     */
    function getLaunchTimestamp() external view override returns (uint256) {
        return _launchTimestamp;
    }
    
    /**
     * @dev Check if token is launched
     * @return True if token is launched
     */
    function isLaunched() external view override returns (bool) {
        return _isLaunched;
    }
    
    /**
     * @dev Check if early sell tax is enabled
     * @return True if early sell tax is enabled
     */
    function isEarlySellTaxEnabled() external view override returns (bool) {
        return _isEarlySellTaxEnabled;
    }
    
    /**
     * @dev Get the total charity donations tracked
     * @return Total charity donations in wei
     */
    function getTotalCharityDonations() external view override returns (uint256) {
        return _totalCharityDonations;
    }
    
    /**
     * @dev Get the early sell tax rates
     * @return Day 1, Day 2, and Day 3 tax rates in basis points
     */
    function getTaxRates() external pure override returns (uint16, uint16, uint16) {
        return (TAX_RATE_DAY_1, TAX_RATE_DAY_2, TAX_RATE_DAY_3);
    }
    
    /**
     * @dev Get the early sell tax durations
     * @return Day 1, Day 2, and Day 3 durations in seconds
     */
    function getTaxDurations() external view override returns (uint256, uint256, uint256) {
        return (_taxRateDayOne, _taxRateDayTwo, _taxRateDayThree);
    }
    
    // ================ External Interface Function Implementations ================
    
    /**
     * @dev Set excluded from fee status for an account (token only)
     * @param account Account to update
     * @param excluded Whether the account is excluded from fees
     */
    function _setExcludedFromFee(address account, bool excluded) external override {
        require(msg.sender == _tokenAddress, "Only token contract can call");
        require(_isTokenAddressVerified, "Token address not verified");
        
        _isExcludedFromFee[account] = excluded;
        
        emit ExcludedFromFeeUpdated(account, excluded);
    }
    
    /**
     * @dev Set a known DEX address (token only)
     * @param dexAddress The DEX address
     * @param isDex Whether the address is a DEX
     */
    function _setKnownDex(address dexAddress, bool isDex) external override {
        require(msg.sender == _tokenAddress, "Only token contract can call");
        require(_isTokenAddressVerified, "Token address not verified");
        
        _isKnownDex[dexAddress] = isDex;
        
        emit KnownDexUpdated(dexAddress, isDex);
    }
    
    /**
     * @dev Update the charity wallet address (token only)
     * @param newCharityWallet New charity wallet address
     */
    function _updateCharityWallet(address newCharityWallet) external override {
        require(msg.sender == _tokenAddress, "Only token contract can call");
        require(_isTokenAddressVerified, "Token address not verified");
        require(newCharityWallet != address(0), "Charity wallet cannot be zero address");
        
        _charityWallet = newCharityWallet;
        
        // Exclude new charity wallet from fees
        _isExcludedFromFee[newCharityWallet] = true;
        
        emit CharityWalletUpdated(newCharityWallet);
    }
    
    /**
     * @dev Disable early sell tax permanently (token only)
     */
    function _disableEarlySellTax() external override {
        require(msg.sender == _tokenAddress, "Only token contract can call");
        require(_isTokenAddressVerified, "Token address not verified");
        
        require(_isEarlySellTaxEnabled, "Early sell tax already disabled");
        
        _isEarlySellTaxEnabled = false;
        
        emit EarlySellTaxDisabled();
    }
}
