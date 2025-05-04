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
    mapping(address => bool) private dexAddresses;
    
    // Launch tracking
    uint256 private _launchTimestamp;
    bool private _isLaunched;
    
    // Custom errors for gas efficiency - prefixed with "Fees" to avoid naming collisions
    error FeesNotDOVEToken();
    error FeesZeroAddressNotAllowed();
    error FeesTokenAlreadyLaunched();
    error FeesEarlySellTaxAlreadyDisabled();
    
    // ================ Modifiers ================
    
    /**
     * @dev Ensures only the DOVE token can call this contract
     */
    modifier onlyDOVE() {
        if (msg.sender != _doveToken) {
            revert FeesNotDOVEToken();
        }
        _;
    }
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor initializes the DOVE fee manager
     * @param doveToken Address of the DOVE token
     * @param initialCharityWallet Initial charity wallet address
     */
    constructor(address doveToken, address initialCharityWallet) {
        if (doveToken == address(0)) {
            revert FeesZeroAddressNotAllowed();
        }
        if (initialCharityWallet == address(0)) {
            revert FeesZeroAddressNotAllowed();
        }
        
        _doveToken = doveToken;
        _charityWallet = initialCharityWallet;
    }
    
    // ================ External Functions ================
    
    /**
     * @dev Process all fees for a transfer
     * @param sender Sender of the transfer
     * @param recipient Recipient of the transfer
     * @param amount Amount being transferred
     * @return netAmount Net amount after fees
     */
    function processFees(
        address sender,
        address recipient,
        uint256 amount
    ) external onlyDOVE returns (uint256 netAmount) {
        // Skip fees for excluded addresses and always fee exempt addresses
        if (_isExcludedFromFee[sender] || _isExcludedFromFee[recipient] ||
            IDOVE(_doveToken).isAlwaysFeeExempt(sender) || IDOVE(_doveToken).isAlwaysFeeExempt(recipient)) {
            return amount;
        }
        
        // Initialize net amount
        netAmount = amount;
        
        // Apply charity fee (applies to all non-excluded transfers)
        // Cache fee calculation result for gas optimization
        uint256 charityFeeAmount = FeeLibrary.calculateCharityFee(amount);
        
        // Only process if there's an actual fee and charity wallet is set
        if (charityFeeAmount > 0 && _charityWallet != address(0)) {
            // CHECKS-EFFECTS: Reduce the net amount by the fee
            unchecked {
                netAmount = netAmount - charityFeeAmount;
            }
            
            // Instead of calling the transferFeeFromContract directly, which can cause reentrancy,
            // set the values for direct transfer
            if (_charityWallet != address(0)) {
                // INTERACTIONS: Transfer fee to charity wallet - call super._transfer to avoid reprocessing fees
                try IDOVE(_doveToken).transferFeeFromContract(sender, _charityWallet, charityFeeAmount) returns (bool success) {
                    if (success) {
                        emit CharityFeeTaken(sender, recipient, charityFeeAmount);
                    } else {
                        // If fee transfer fails, add it back to net amount
                        unchecked {
                            netAmount = netAmount + charityFeeAmount;
                        }
                    }
                } catch {
                    // If the transfer call fails completely, add the fee back to net amount
                    unchecked {
                        netAmount = netAmount + charityFeeAmount;
                    }
                }
            }
        }
        
        // Apply early sell tax only for DEX sells
        if (_isEarlySellTaxEnabled && dexAddresses[recipient]) {
            // Cache timestamp calculation to avoid multiple storage reads
            uint256 timeSinceLaunch;
            unchecked {
                timeSinceLaunch = block.timestamp - _launchTimestamp;
            }
            
            uint256 sellTaxAmount = FeeLibrary.calculateEarlySellTax(netAmount, timeSinceLaunch);
            
            if (sellTaxAmount > 0) {
                // CHECKS-EFFECTS: Reduce the net amount by the tax
                unchecked {
                    netAmount = netAmount - sellTaxAmount;
                }
                
                // INTERACTIONS: Burn the tax amount (sent to dead address)
                bool success = IDOVE(_doveToken).burnFeeFromContract(sender, sellTaxAmount);
                if (success) {
                    emit EarlySellTaxTaken(sender, recipient, sellTaxAmount);
                } else {
                    // If burn fails, add it back to net amount
                    unchecked {
                        netAmount = netAmount + sellTaxAmount;
                    }
                }
            }
        }
        
        return netAmount;
    }
    
    /**
     * @dev Set charity wallet address
     * @param newCharityWallet New charity wallet address
     */
    function setCharityWallet(address newCharityWallet) external onlyDOVE {
        if (newCharityWallet == address(0)) {
            revert FeesZeroAddressNotAllowed();
        }
        
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
    function setExcludedFromFee(address account, bool excluded) external onlyDOVE {
        if (account == address(0)) {
            revert FeesZeroAddressNotAllowed();
        }
        
        _isExcludedFromFee[account] = excluded;
        
        // Emit event from DOVE token
        IDOVE(_doveToken).emitExcludedFromFeeUpdated(account, excluded);
    }
    
    /**
     * @dev Sets the DEX status of an address.
     * @param dexAddress Address to set DEX status for
     * @param _isDex Boolean indicating if the address is a DEX
     */
    function setDexStatus(address dexAddress, bool _isDex) external onlyDOVE {
        if (dexAddress == address(0)) {
            revert FeesZeroAddressNotAllowed();
        }
        
        dexAddresses[dexAddress] = _isDex;
        
        // Emit event from DOVE token
        IDOVE(_doveToken).emitDexStatusUpdated(dexAddress, _isDex);
    }
    
    /**
     * @dev Disable early sell tax permanently
     */
    function disableEarlySellTax() external onlyDOVE {
        if (!_isEarlySellTaxEnabled) {
            revert FeesEarlySellTaxAlreadyDisabled();
        }
        
        _isEarlySellTaxEnabled = false;
        
        // Emit event from DOVE token
        IDOVE(_doveToken).emitEarlySellTaxDisabled();
    }
    
    /**
     * @dev Record token launch
     */
    function recordLaunch() external onlyDOVE {
        if (_isLaunched) {
            revert FeesTokenAlreadyLaunched();
        }
        
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
    function getDexStatus(address account) external view returns (bool) {
        return dexAddresses[account];
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
