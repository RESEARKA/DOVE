// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IDOVEFees.sol";

/**
 * @title DOVE Fee Management
 * @dev Implementation of fee mechanisms for DOVE token (charity fee and early-sell tax)
 */
contract DOVEFees is Ownable2Step, IDOVEFees {
    
    // ================ Constants ================
    
    // Charity fee: 0.5% of transactions sent to charity wallet
    uint16 private constant CHARITY_FEE = 50; // 50 = 0.50%
    
    // Early sell tax rates (in basis points)
    uint16 private constant TAX_RATE_DAY_1 = 300; // 3% for first 24h
    uint16 private constant TAX_RATE_DAY_2 = 200; // 2% for 24-48h
    uint16 private constant TAX_RATE_DAY_3 = 100; // 1% for 48-72h
    
    // ================ State Variables ================
    
    // Timestamp of first transfer (launch time)
    uint256 private _launchTimestamp;
    
    // Flag to indicate if token is officially launched
    bool private _isLaunched = false;
    
    // Flag to control if early sell tax is enabled
    bool private _isEarlySellTaxEnabled = true;
    
    // Charity wallet to receive fees
    address private _charityWallet;
    
    // Total amount donated to charity
    uint256 private _totalCharityDonations;
    
    // Addresses marked as known DEXes
    mapping(address => bool) private _isKnownDex;
    
    // Addresses excluded from fees
    mapping(address => bool) private _isExcludedFromFee;
    
    // Tax rate duration in seconds
    uint256 private _taxRateDayOne = 1 days;
    uint256 private _taxRateDayTwo = 2 days;
    uint256 private _taxRateDayThree = 3 days;
    
    // DOVE token address (automatically set when used)
    address private _tokenAddress;
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor initializes fee module with charity wallet
     * @param initialCharityWallet Address to receive charity fees
     */
    constructor(address initialCharityWallet) {
        require(initialCharityWallet != address(0), "Charity wallet cannot be zero address");
        
        // Set charity wallet
        _charityWallet = initialCharityWallet;
    }
    
    // ================ External View Functions ================
    
    /**
     * @dev See {IDOVEFees-getCharityFee}
     */
    function getCharityFee() external pure returns (uint16) {
        return CHARITY_FEE;
    }
    
    /**
     * @dev See {IDOVEFees-getCharityWallet}
     */
    function getCharityWallet() external view returns (address) {
        return _charityWallet;
    }
    
    /**
     * @dev See {IDOVEFees-getTotalCharityDonations}
     */
    function getTotalCharityDonations() external view returns (uint256) {
        return _totalCharityDonations;
    }
    
    /**
     * @dev See {IDOVEFees-getLaunchTimestamp}
     */
    function getLaunchTimestamp() external view returns (uint256) {
        return _launchTimestamp;
    }
    
    /**
     * @dev See {IDOVEFees-isEarlySellTaxEnabled}
     */
    function isEarlySellTaxEnabled() external view returns (bool) {
        return _isEarlySellTaxEnabled;
    }
    
    /**
     * @dev See {IDOVEFees-isLaunched}
     */
    function isLaunched() external view returns (bool) {
        return _isLaunched;
    }
    
    /**
     * @dev See {IDOVEFees-isExcludedFromFee}
     */
    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcludedFromFee[account];
    }
    
    /**
     * @dev See {IDOVEFees-isKnownDex}
     */
    function isKnownDex(address dexAddress) external view returns (bool) {
        return _isKnownDex[dexAddress];
    }
    
    /**
     * @dev See {IDOVEFees-getEarlySellTaxFor}
     */
    function getEarlySellTaxFor(address) external view returns (uint16) {
        // Early check - if tax is disabled or token not launched, no tax applies
        if (!_isEarlySellTaxEnabled || !_isLaunched) {
            return 0;
        }
        
        uint256 timeElapsed = block.timestamp - _launchTimestamp;
        
        if (timeElapsed < _taxRateDayOne) {
            return TAX_RATE_DAY_1;
        } else if (timeElapsed < _taxRateDayTwo) {
            return TAX_RATE_DAY_2;
        } else if (timeElapsed < _taxRateDayThree) {
            return TAX_RATE_DAY_3;
        } else {
            return 0;
        }
    }
    
    /**
     * @dev See {IDOVEFees-getTaxRateDurations}
     */
    function getTaxRateDurations() external view returns (uint256, uint256, uint256) {
        return (_taxRateDayOne, _taxRateDayTwo, _taxRateDayThree);
    }
    
    // ================ Internal Functions (For Admin/Token) ================
    
    /**
     * @dev Set launched status for DOVEToken/Admin
     * @param launchTimestamp The timestamp to set as launch time
     */
    function _setLaunched(uint256 launchTimestamp) external onlyOwner {
        require(!_isLaunched, "Token already launched");
        _isLaunched = true;
        _launchTimestamp = launchTimestamp;
    }
    
    /**
     * @dev Set charity donation amount - function for tracking
     * @param amount Amount being donated
     */
    function _addCharityDonation(uint256 amount) external {
        // Only allow token contract to call this
        if (_tokenAddress == address(0)) {
            _tokenAddress = msg.sender;
        }
        
        require(msg.sender == _tokenAddress, "Only token can call");
        _totalCharityDonations += amount;
    }
    
    /**
     * @dev Set an address to be excluded from fee
     * @param account Address to exclude
     * @param excluded Whether to exclude or include
     */
    function _setExcludedFromFee(address account, bool excluded) external onlyOwner {
        _isExcludedFromFee[account] = excluded;
    }
    
    /**
     * @dev Set an address as known DEX
     * @param dexAddress Address to mark as DEX
     * @param isDex Whether this address is a DEX or not
     */
    function _setKnownDex(address dexAddress, bool isDex) external onlyOwner {
        _isKnownDex[dexAddress] = isDex;
    }
    
    /**
     * @dev Update charity wallet
     * @param newCharityWallet New charity wallet address
     */
    function _updateCharityWallet(address newCharityWallet) external onlyOwner {
        require(newCharityWallet != address(0), "Charity wallet cannot be zero address");
        _charityWallet = newCharityWallet;
    }
    
    /**
     * @dev Update tax rate durations
     * @param day1 Duration for first tax rate (in seconds)
     * @param day2 Duration for second tax rate (in seconds)
     * @param day3 Duration for third tax rate (in seconds)
     */
    function _updateTaxRateDurations(
        uint256 day1,
        uint256 day2,
        uint256 day3
    ) external onlyOwner {
        require(day1 < day2 && day2 < day3, "Invalid durations: must be increasing");
        _taxRateDayOne = day1;
        _taxRateDayTwo = day2;
        _taxRateDayThree = day3;
    }
    
    /**
     * @dev Disable early sell tax
     */
    function _disableEarlySellTax() external onlyOwner {
        _isEarlySellTaxEnabled = false;
    }
}
