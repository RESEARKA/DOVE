// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./DOVETokenAddressManager.sol";

/**
 * @title DOVE Fee Controller
 * @dev Handles fee management operations like exclusions and configuration
 */
abstract contract DOVEFeeController is DOVETokenAddressManager {
    // ================ Events ================
    event TokenLaunched(uint256 launchTimestamp);
    event CharityDonationAdded(uint256 amount, uint256 newTotal);
    event EarlySellTaxDisabled();
    event ExcludedFromFeeUpdated(address indexed account, bool excluded);
    event KnownDexUpdated(address indexed dexAddress, bool isDex);
    event CharityWalletUpdated(address oldWallet, address newCharityWallet);
    event TaxRateDurationsUpdated(uint256 day1Duration, uint256 day2Duration, uint256 day3Duration);
    
    /**
     * @dev Exclude an account from fees
     * @param account Address to exclude
     * @param excluded Whether to exclude the account
     */
    function setExcludedFromFee(address account, bool excluded) external onlyRole(FEE_MANAGER_ROLE) {
        _isExcludedFromFee[account] = excluded;
        
        // Emit event for transparency when fee exclusion status changes
        emit ExcludedFromFeeUpdated(account, excluded);
    }
    
    /**
     * @dev Set a known DEX address
     * @param dexAddress Address of the DEX
     * @param isDex Whether the address is a DEX
     */
    function setKnownDex(address dexAddress, bool isDex) external onlyRole(FEE_MANAGER_ROLE) {
        _isKnownDex[dexAddress] = isDex;
        
        emit KnownDexUpdated(dexAddress, isDex);
    }
    
    /**
     * @dev Disable early sell tax permanently (emergency function)
     */
    function disableEarlySellTax() external onlyRole(EMERGENCY_ADMIN_ROLE) {
        require(_isEarlySellTaxEnabled, "Early sell tax already disabled");
        
        _isEarlySellTaxEnabled = false;
        
        emit EarlySellTaxDisabled();
    }
    
    /**
     * @dev Update charity wallet address
     * @param newCharityWallet New charity wallet address
     */
    function setCharityWallet(address newCharityWallet) external onlyRole(FEE_MANAGER_ROLE) {
        require(newCharityWallet != address(0), "Charity wallet cannot be zero address");
        
        // Update charity wallet
        address oldWallet = _charityWallet;
        _charityWallet = newCharityWallet;
        
        // Exclude new charity wallet from fees
        _isExcludedFromFee[newCharityWallet] = true;
        
        emit CharityWalletUpdated(oldWallet, newCharityWallet);
    }
    
    /**
     * @dev Update tax rate durations
     * @param day1Duration Duration of day 1 tax rate
     * @param day2Duration Duration of day 2 tax rate
     * @param day3Duration Duration of day 3 tax rate
     */
    function setTaxRateDurations(
        uint256 day1Duration,
        uint256 day2Duration,
        uint256 day3Duration
    ) external onlyRole(FEE_MANAGER_ROLE) {
        // Validate durations
        require(day1Duration >= MIN_TAX_DURATION, "Day 1 duration too short");
        require(day2Duration >= MIN_TAX_DURATION, "Day 2 duration too short");
        require(day3Duration >= MIN_TAX_DURATION, "Day 3 duration too short");
        
        require(day1Duration <= MAX_TAX_DURATION, "Day 1 duration too long");
        require(day2Duration <= MAX_TAX_DURATION, "Day 2 duration too long");
        require(day3Duration <= MAX_TAX_DURATION, "Day 3 duration too long");
        
        uint256 totalDuration = day1Duration + day2Duration + day3Duration;
        require(totalDuration <= MAX_TOTAL_TAX_DURATION, "Total duration too long");
        
        _taxRateDayOne = day1Duration;
        _taxRateDayTwo = day2Duration;
        _taxRateDayThree = day3Duration;
        
        emit TaxRateDurationsUpdated(day1Duration, day2Duration, day3Duration);
    }
    
    // ================ External Control Functions (Token Only) ================
    
    /**
     * @dev Set token as launched (called by token on first transfer)
     * @param launchTimestamp Timestamp when token launched
     */
    function _setLaunched(uint256 launchTimestamp) external {
        require(msg.sender == _tokenAddress, "Only token contract can call");
        require(_isTokenAddressVerified, "Token address not verified");
        require(!_isLaunched, "Token already launched");
        
        _isLaunched = true;
        _launchTimestamp = launchTimestamp;
        
        emit TokenLaunched(launchTimestamp);
    }
    
    /**
     * @dev Add charity donation to total tracked amount
     * @param amount Amount donated to charity
     */
    function _addCharityDonation(uint256 amount) external {
        require(msg.sender == _tokenAddress, "Only token contract can call");
        require(_isTokenAddressVerified, "Token address not verified");
        
        _totalCharityDonations += amount;
        
        emit CharityDonationAdded(amount, _totalCharityDonations);
    }
}
