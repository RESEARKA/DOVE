// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../utils/FeeLibrary.sol";
import "../interfaces/IDOVE.sol";

/**
 * @title DOVE Fee Manager
 * @dev Handles fee calculations and processing for the DOVE token
 * Encapsulates fee-related logic to maintain separation of concerns
 */
contract DOVEFees is ReentrancyGuard {
    // ================ Events ================
    
    event CharityFeeTaken(address indexed from, address indexed to, uint256 amount);
    event EarlySellTaxTaken(address indexed from, address indexed dex, uint256 amount);
    
    // ================ State Variables ================
    
    // Main token reference
    address private immutable _doveToken;
    
    // Fee configuration
    address private _charityWallet;
    bool private _isEarlySellTaxEnabled = true;
    
    // Exclusions from fees
    mapping(address => bool) private _isExcludedFromFee;
    
    // DEX addresses for sell tax calculation
    mapping(address => bool) private _isDex;
    
    // Launch tracking
    uint256 private _launchTimestamp;
    bool private _isLaunched;
    
    // ================ Modifiers ================
    
    /**
     * @dev Ensures only the DOVE token can call this contract
     */
    modifier onlyDOVE() {
        require(msg.sender == _doveToken, "Caller is not the DOVE token");
        _;
    }
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor initializes the DOVE fee manager
     * @param doveToken Address of the DOVE token
     * @param initialCharityWallet Initial charity wallet address
     */
    constructor(address doveToken, address initialCharityWallet) {
        require(doveToken != address(0), "DOVE token cannot be zero address");
        require(initialCharityWallet != address(0), "Charity wallet cannot be zero address");
        
        _doveToken = doveToken;
        _charityWallet = initialCharityWallet;
    }
    
    // ================ External Functions ================
    
    /**
     * @dev Process fees for a token transfer
     * @param sender Sender address
     * @param recipient Recipient address
     * @param amount Token amount being transferred
     * @return netAmount Amount after fees are deducted
     */
    function processFees(
        address sender,
        address recipient,
        uint256 amount
    ) external onlyDOVE nonReentrant returns (uint256 netAmount) {
        // Skip fees for excluded addresses or if token not launched
        if (!_isLaunched || _isExcludedFromFee[sender]) {
            return amount;
        }
        
        // Initialize net amount
        netAmount = amount;
        
        // Apply charity fee (applies to all non-excluded transfers)
        uint256 charityFeeAmount = FeeLibrary.calculateCharityFee(amount);
        if (charityFeeAmount > 0 && _charityWallet != address(0)) {
            // CHECKS-EFFECTS: Reduce the net amount by the fee
            netAmount -= charityFeeAmount;
            
            // INTERACTIONS: Transfer fee to charity wallet
            bool success = IDOVE(_doveToken).transferFeeFromContract(sender, _charityWallet, charityFeeAmount);
            if (success) {
                emit CharityFeeTaken(sender, recipient, charityFeeAmount);
            } else {
                // If fee transfer fails, add it back to net amount
                netAmount += charityFeeAmount;
            }
        }
        
        // Apply early sell tax only for DEX sells
        if (_isEarlySellTaxEnabled && _isDex[recipient]) {
            uint256 timeSinceLaunch = block.timestamp - _launchTimestamp;
            uint256 sellTaxAmount = FeeLibrary.calculateEarlySellTax(netAmount, timeSinceLaunch);
            
            if (sellTaxAmount > 0) {
                // CHECKS-EFFECTS: Reduce the net amount by the tax
                netAmount -= sellTaxAmount;
                
                // INTERACTIONS: Burn the tax amount (sent to dead address)
                bool success = IDOVE(_doveToken).burnFeeFromContract(sender, sellTaxAmount);
                if (success) {
                    emit EarlySellTaxTaken(sender, recipient, sellTaxAmount);
                } else {
                    // If burn fails, add it back to net amount
                    netAmount += sellTaxAmount;
                }
            }
        }
        
        return netAmount;
    }
    
    /**
     * @dev Set charity wallet address
     * @param newCharityWallet New charity wallet address
     */
    function setCharityWallet(address newCharityWallet) external onlyDOVE nonReentrant {
        require(newCharityWallet != address(0), "New charity wallet cannot be zero address");
        
        address oldWallet = _charityWallet;
        _charityWallet = newCharityWallet;
        
        // Emit event from DOVE token
        IDOVE(_doveToken).emitCharityWalletUpdated(oldWallet, newCharityWallet);
    }
    
    /**
     * @dev Set an address as excluded or included from fees
     * @param account Address to update
     * @param excluded Whether to exclude from fees
     */
    function setExcludedFromFee(address account, bool excluded) external onlyDOVE nonReentrant {
        require(account != address(0), "Account cannot be zero address");
        
        _isExcludedFromFee[account] = excluded;
        
        // Emit event from DOVE token
        IDOVE(_doveToken).emitExcludedFromFeeUpdated(account, excluded);
    }
    
    /**
     * @dev Set a DEX address status
     * @param dexAddress Address to set status for
     * @param isDex Whether the address is a DEX
     */
    function setDexStatus(address dexAddress, bool isDex) external onlyDOVE nonReentrant {
        require(dexAddress != address(0), "DEX address cannot be zero address");
        
        _isDex[dexAddress] = isDex;
        
        // Emit event from DOVE token
        IDOVE(_doveToken).emitDexStatusUpdated(dexAddress, isDex);
    }
    
    /**
     * @dev Disable early sell tax permanently
     */
    function disableEarlySellTax() external onlyDOVE nonReentrant {
        require(_isEarlySellTaxEnabled, "Early sell tax already disabled");
        _isEarlySellTaxEnabled = false;
        
        // Emit event from DOVE token
        IDOVE(_doveToken).emitEarlySellTaxDisabled();
    }
    
    /**
     * @dev Record token launch
     */
    function recordLaunch() external onlyDOVE nonReentrant {
        require(!_isLaunched, "Token already launched");
        _isLaunched = true;
        _launchTimestamp = block.timestamp;
    }
    
    // ================ View Functions ================
    
    /**
     * @dev Get charity wallet address
     * @return The charity wallet address
     */
    function getCharityWallet() external view returns (address) {
        return _charityWallet;
    }
    
    /**
     * @dev Check if an address is excluded from fees
     * @param account Address to check
     * @return Whether the address is excluded from fees
     */
    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcludedFromFee[account];
    }
    
    /**
     * @dev Check if an address is a DEX
     * @param account Address to check
     * @return Whether the address is a DEX
     */
    function isDex(address account) external view returns (bool) {
        return _isDex[account];
    }
    
    /**
     * @dev Check if the token is launched
     * @return Whether the token is launched
     */
    function isLaunched() external view returns (bool) {
        return _isLaunched;
    }
    
    /**
     * @dev Get launch timestamp
     * @return The launch timestamp
     */
    function getLaunchTimestamp() external view returns (uint256) {
        return _launchTimestamp;
    }
    
    /**
     * @dev Check if early sell tax is enabled
     * @return Whether early sell tax is enabled
     */
    function isEarlySellTaxEnabled() external view returns (bool) {
        return _isEarlySellTaxEnabled;
    }
}
