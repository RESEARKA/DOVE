// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IDOVE.sol";
import "../interfaces/IDOVEAdmin.sol";
import "../utils/FeeLibrary.sol";

/**
 * @title DOVE Token
 * @dev Implementation of the DOVE token with charity fee and early-sell tax mechanisms
 * 
 * IMPORTANT FEE STRUCTURE NOTICE:
 * This token implements two types of fees that affect transfer amounts:
 * 1. Charity Fee (0.5%): Applied to all transfers except excluded addresses
 *    - Fee is sent to a designated charity wallet
 * 2. Early Sell Tax (5% to 0%): Applied only when selling to DEX in first 72 hours
 *    - Tax rate decreases over time (5%, 3%, 1%, then 0%)
 *    - Tax amount is burned from supply
 * 
 * Users should be aware that the amount received by the recipient will be
 * less than the amount sent by the sender due to these fees.
 */
contract DOVE is ERC20, AccessControl, Pausable, ReentrancyGuard, IDOVE {
    // ================ Constants ================
    
    // Total supply: 100 billion tokens (100,000,000,000 with 18 decimals)
    uint256 public constant TOTAL_SUPPLY = 100_000_000_000 * 10**18;
    
    // Maximum transaction amount: 1% of total supply
    uint256 private immutable _maxTransactionAmount;
    
    // ================ State Variables ================
    
    // Admin contract reference - handles administrative functions
    IDOVEAdmin private immutable _adminContract;
    
    // Charity wallet - receives the charity fee
    address private _charityWallet;
    
    // Launch status
    bool private _isLaunched;
    uint256 private _launchTimestamp;
    
    // Fee configuration
    bool private _isEarlySellTaxEnabled = true;
    bool private _isMaxTxLimitEnabled = true;
    
    // Address mappings
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isDex;
    
    // Fee statistics
    uint256 private _totalCharityDonations;
    
    // ================ Events ================
    
    // Events inherited from IDOVE interface
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor initializes the DOVE token
     * @param adminContractAddress Address of the admin contract
     * @param initialCharityWallet Initial charity wallet address
     */
    constructor(
        address adminContractAddress,
        address initialCharityWallet
    ) ERC20("DOVE Token", "DOVE") {
        require(adminContractAddress != address(0), "Admin contract cannot be zero address");
        require(initialCharityWallet != address(0), "Charity wallet cannot be zero address");
        
        // Set up admin contract and charity wallet
        _adminContract = IDOVEAdmin(adminContractAddress);
        _charityWallet = initialCharityWallet;
        
        // Set max transaction limit to 1% of supply
        _maxTransactionAmount = TOTAL_SUPPLY / 100;
        
        // Mint total supply to deployer
        _mint(msg.sender, TOTAL_SUPPLY);
        
        // Exclude deployer, this contract, and charity wallet from fees
        _isExcludedFromFee[msg.sender] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[initialCharityWallet] = true;
    }
    
    // ================ External View Functions ================
    
    /**
     * @dev See {IDOVE-getCharityFee} - returns charity fee in basis points
     */
    function getCharityFee() external pure override returns (uint16) {
        return FeeLibrary.getCharityFeePercentage();
    }
    
    /**
     * @dev See {IDOVE-getCharityWallet} - returns current charity wallet
     */
    function getCharityWallet() external view override returns (address) {
        return _charityWallet;
    }
    
    /**
     * @dev See {IDOVE-getLaunchTimestamp} - returns token launch timestamp
     */
    function getLaunchTimestamp() external view override returns (uint256) {
        return _launchTimestamp;
    }
    
    /**
     * @dev See {IDOVE-getTotalCharityDonations} - returns total tokens donated
     */
    function getTotalCharityDonations() external view override returns (uint256) {
        return _totalCharityDonations;
    }
    
    /**
     * @dev See {IDOVE-isExcludedFromFee} - checks if address is excluded from fees
     */
    function isExcludedFromFee(address account) external view override returns (bool) {
        return _isExcludedFromFee[account];
    }
    
    /**
     * @dev See {IDOVE-getEarlySellTaxFor} - returns early sell tax rate for an address
     */
    function getEarlySellTaxFor(address seller) external view override returns (uint16) {
        if (!_isLaunched || !_isEarlySellTaxEnabled || _isExcludedFromFee[seller]) {
            return 0;
        }
        
        uint256 timeSinceLaunch = block.timestamp - _launchTimestamp;
        return FeeLibrary.getEarlySellTaxRate(timeSinceLaunch);
    }
    
    /**
     * @dev See {IDOVE-isEarlySellTaxEnabled} - checks if early sell tax is enabled
     */
    function isEarlySellTaxEnabled() external view override returns (bool) {
        return _isEarlySellTaxEnabled;
    }
    
    /**
     * @dev See {IDOVE-isLaunched} - checks if token is launched
     */
    function isLaunched() external view override returns (bool) {
        return _isLaunched;
    }
    
    /**
     * @dev See {IDOVE-getMaxTransactionAmount} - returns max tx amount
     */
    function getMaxTransactionAmount() external view override returns (uint256) {
        if (!_isMaxTxLimitEnabled) {
            return type(uint256).max;
        }
        return _maxTransactionAmount;
    }
    
    // ================ Admin Functions ================
    
    /**
     * @dev Sets the charity wallet address
     * @param newCharityWallet New charity wallet address
     * 
     * Can only be called by the admin contract
     */
    function setCharityWallet(address newCharityWallet) external {
        require(msg.sender == address(_adminContract), "Caller is not the admin contract");
        require(newCharityWallet != address(0), "New charity wallet cannot be zero address");
        
        address oldWallet = _charityWallet;
        _charityWallet = newCharityWallet;
        
        // Exclude new charity wallet from fees
        _isExcludedFromFee[newCharityWallet] = true;
        
        emit CharityWalletUpdated(oldWallet, newCharityWallet);
    }
    
    /**
     * @dev Excludes or includes an address from fees
     * @param account Address to update
     * @param excluded Whether to exclude from fees
     * 
     * Can only be called by the admin contract
     */
    function setExcludedFromFee(address account, bool excluded) external {
        require(msg.sender == address(_adminContract), "Caller is not the admin contract");
        require(account != address(0), "Account cannot be zero address");
        
        _isExcludedFromFee[account] = excluded;
        
        emit ExcludedFromFeeUpdated(account, excluded);
    }
    
    /**
     * @dev Sets DEX status for an address
     * @param dexAddress Address to update
     * @param isDexAddress Whether address is a DEX
     * 
     * Can only be called by the admin contract
     */
    function setDexStatus(address dexAddress, bool isDexAddress) external {
        require(msg.sender == address(_adminContract), "Caller is not the admin contract");
        require(dexAddress != address(0), "DEX address cannot be zero address");
        
        _isDex[dexAddress] = isDexAddress;
        
        emit DexStatusUpdated(dexAddress, isDexAddress);
    }
    
    /**
     * @dev Launches the token, enabling transfers
     * 
     * Can only be called by the admin contract
     */
    function launch() external {
        require(msg.sender == address(_adminContract), "Caller is not the admin contract");
        require(!_isLaunched, "Token already launched");
        
        _isLaunched = true;
        _launchTimestamp = block.timestamp;
        
        emit TokenLaunched(_launchTimestamp);
    }
    
    /**
     * @dev Disables early sell tax permanently
     * 
     * Can only be called by the admin contract
     */
    function disableEarlySellTax() external {
        require(msg.sender == address(_adminContract), "Caller is not the admin contract");
        require(_isEarlySellTaxEnabled, "Early sell tax already disabled");
        
        _isEarlySellTaxEnabled = false;
        
        emit EarlySellTaxDisabled();
    }
    
    /**
     * @dev Disables max transaction limit permanently
     * 
     * Can only be called by the admin contract
     */
    function disableMaxTxLimit() external {
        require(msg.sender == address(_adminContract), "Caller is not the admin contract");
        require(_isMaxTxLimitEnabled, "Max transaction limit already disabled");
        
        _isMaxTxLimitEnabled = false;
        
        emit MaxTransactionLimitDisabled();
    }
    
    /**
     * @dev Pauses token transfers
     * 
     * Can only be called by the admin contract
     */
    function pause() external {
        require(msg.sender == address(_adminContract), "Caller is not the admin contract");
        _pause();
    }
    
    /**
     * @dev Unpauses token transfers
     * 
     * Can only be called by the admin contract
     */
    function unpause() external {
        require(msg.sender == address(_adminContract), "Caller is not the admin contract");
        _unpause();
    }
    
    // ================ Internal Functions ================
    
    /**
     * @dev Handles fee calculation and collection
     * @param sender Sender address
     * @param recipient Recipient address 
     * @param amount Transfer amount
     * @return netAmount Amount after fees
     */
    function _handleFees(
        address sender,
        address recipient,
        uint256 amount
    ) private returns (uint256 netAmount) {
        // Skip fees for excluded addresses or if token not launched
        if (!_isLaunched || _isExcludedFromFee[sender]) {
            return amount;
        }
        
        // Check if this is a sell transaction to DEX
        bool isEarlySellTaxApplicable = _isDex[recipient];
        
        // Calculate all applicable fees
        (
            uint256 charityFee,
            uint256 sellTax,
            uint256 totalFee,
            uint256 amountAfterFees
        ) = FeeLibrary.calculateAllFees(
            amount,
            block.timestamp - _launchTimestamp,
            isEarlySellTaxApplicable,
            _isEarlySellTaxEnabled
        );
        
        // === CHECKS-EFFECTS PATTERN: Update state before interactions ===
        
        // Update charity donation tracking if applicable
        if (charityFee > 0) {
            _totalCharityDonations += charityFee;
        }
        
        // === INTERACTIONS: External calls after state changes ===
        
        // Process charity fee if any
        if (charityFee > 0) {
            // Transfer charity fee to charity wallet
            super._transfer(sender, _charityWallet, charityFee);
            emit CharityDonation(sender, charityFee);
        }
        
        // Process early sell tax if any
        if (sellTax > 0) {
            // Burn the early sell tax
            super._burn(sender, sellTax);
            emit EarlySellTaxBurned(sender, sellTax);
        }
        
        return amountAfterFees;
    }
    
    /**
     * @dev Check max transaction limit
     * @param sender Sender address
     * @param amount Transfer amount
     */
    function _checkMaxTxLimit(address sender, uint256 amount) private view {
        // Skip max tx check if disabled or sender is excluded
        if (!_isMaxTxLimitEnabled || _isExcludedFromFee[sender]) {
            return;
        }
        
        require(amount <= _maxTransactionAmount, "Transfer amount exceeds maximum");
    }
    
    /**
     * @dev See {ERC20-_transfer}
     * Overrides transfer with fee handling
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override whenNotPaused nonReentrant {
        require(sender != address(0), "Transfer from zero address");
        require(recipient != address(0), "Transfer to zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        
        // Check max transaction limit
        _checkMaxTxLimit(sender, amount);
        
        // Calculate net amount after fees
        uint256 netAmount = _handleFees(sender, recipient, amount);
        
        // Transfer net amount to recipient
        super._transfer(sender, recipient, netAmount);
    }
    
    // ================ Events ================
    
    event ExcludedFromFeeUpdated(address indexed account, bool excluded);
    event DexStatusUpdated(address indexed dexAddress, bool isDex);
}
