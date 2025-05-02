// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IDOVE.sol";
import "../interfaces/IDOVEAdmin.sol";
import "../interfaces/IDOVEFees.sol";
import "../access/RoleManager.sol";
import "../utils/FeeCalculator.sol";

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
 */
contract DOVE is ERC20Permit, ReentrancyGuard, RoleManager, IDOVE {
    // ================ Constants ================
    
    // Base supply: 100 billion tokens with 18 decimals
    uint256 private constant TOTAL_SUPPLY = 100_000_000_000 * 1e18;
    
    // Transaction limits
    uint256 private constant MAX_TX_INITIAL = TOTAL_SUPPLY * 2 / 1000; // 0.2%
    uint256 private constant MAX_TX_AFTER_24H = TOTAL_SUPPLY * 5 / 1000; // 0.5%
    
    // ================ State Variables ================
    
    // Fee management module - handles charity fee and early sell tax
    IDOVEFees public immutable feeManager;
    
    // Admin functionality module - handles owner controls
    IDOVEAdmin public immutable adminManager;
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor initializes the DOVE token with charity wallet
     * @param adminManagerAddress Address of the admin management contract
     * @param feeManagerAddress Address of the fee management contract
     */
    constructor(
        address adminManagerAddress,
        address feeManagerAddress
    ) ERC20("DOVE Token", "DOVE") ERC20Permit("DOVE") {
        require(adminManagerAddress != address(0), "Admin manager cannot be zero address");
        require(feeManagerAddress != address(0), "Fee manager cannot be zero address");

        // Set up contract references
        adminManager = IDOVEAdmin(adminManagerAddress);
        feeManager = IDOVEFees(feeManagerAddress);
        
        // Verify that owner of this contract controls the manager contracts
        // This prevents accidental misconfiguration
        address deployer = msg.sender;
        require(Ownable2Step(adminManagerAddress).owner() == deployer, "Deployer must own admin manager");
        require(Ownable2Step(feeManagerAddress).owner() == deployer, "Deployer must own fee manager");
        
        // Verify that fee manager has correct token role setup
        bytes32 tokenRole = IDOVEFees(feeManagerAddress).TOKEN_ROLE();
        require(!AccessControl(feeManagerAddress).hasRole(tokenRole, address(0)), "Token role not properly initialized");
        
        // Register this token contract with the fee manager using the secure verification mechanism
        IDOVEFees(feeManagerAddress).setTokenAddress(address(this));
        bytes32 confirmationCode = keccak256(abi.encodePacked("VERIFY_TOKEN_ADDRESS", address(this), block.chainid));
        IDOVEFees(feeManagerAddress).verifyTokenAddress(confirmationCode);
        
        // Set up initial roles
        _setupRole(DEFAULT_ADMIN_ROLE, deployer);
        _setupRole(PAUSER_ROLE, deployer);
        _setupRole(MINTER_ROLE, deployer);
        _setupRole(OPERATOR_ROLE, deployer);
        _setupRole(ROLE_MANAGER_ROLE, deployer);
        
        // Initial distribution: 100% to deployer, to be distributed according to tokenomics
        _mint(deployer, TOTAL_SUPPLY);
    }
    
    // ================ External View Functions ================
    
    /**
     * @dev Returns the maximum transaction amount allowed
     * This changes over time: lower at launch, higher after 24 hours
     * @return Maximum transaction amount in token units
     */
    function getMaxTransactionAmount() external view returns (uint256) {
        // Early check - if max tx limit is disabled, return max uint256
        bool isMaxTxLimitEnabled = adminManager.isMaxTxLimitEnabled();
        if (!isMaxTxLimitEnabled) {
            return type(uint256).max;
        }
        
        // If token is not launched yet, use initial limit
        bool isLaunched = feeManager.isLaunched();
        if (!isLaunched) {
            return MAX_TX_INITIAL;
        }
        
        // Calculate time elapsed since launch
        uint256 timeElapsed = block.timestamp - feeManager.getLaunchTimestamp();
        
        // After 24 hours, use higher limit
        if (timeElapsed >= 1 days) {
            return MAX_TX_AFTER_24H;
        }
        
        // Default to initial limit
        return MAX_TX_INITIAL;
    }
    
    /**
     * @dev See {IDOVE-getCharityFee} - delegated to fee manager
     */
    function getCharityFee() external view override returns (uint16) {
        return feeManager.getCharityFee();
    }
    
    /**
     * @dev See {IDOVE-getCharityWallet} - delegated to fee manager
     */
    function getCharityWallet() external view override returns (address) {
        return feeManager.getCharityWallet();
    }
    
    /**
     * @dev See {IDOVE-getLaunchTimestamp} - delegated to fee manager
     */
    function getLaunchTimestamp() external view override returns (uint256) {
        return feeManager.getLaunchTimestamp();
    }
    
    /**
     * @dev See {IDOVE-getTotalCharityDonations} - delegated to fee manager
     */
    function getTotalCharityDonations() external view override returns (uint256) {
        return feeManager.getTotalCharityDonations();
    }
    
    /**
     * @dev See {IDOVE-isLaunched} - delegated to fee manager
     */
    function isLaunched() external view override returns (bool) {
        return feeManager.isLaunched();
    }
    
    /**
     * @dev See {IDOVE-isEarlySellTaxEnabled} - delegated to fee manager
     */
    function isEarlySellTaxEnabled() external view override returns (bool) {
        return feeManager.isEarlySellTaxEnabled();
    }
    
    /**
     * @dev See {IDOVE-isExcludedFromFee} - delegated to fee manager
     */
    function isExcludedFromFee(address account) external view override returns (bool) {
        return feeManager.isExcludedFromFee(account);
    }
    
    /**
     * @dev See {IDOVE-isKnownDex} - delegated to fee manager
     */
    function isKnownDex(address dexAddress) external view override returns (bool) {
        return feeManager.isKnownDex(dexAddress);
    }
    
    /**
     * @dev See {IDOVE-getEarlySellTaxFor} - delegated to fee manager
     */
    function getEarlySellTaxFor(address seller) external view override returns (uint16) {
        return feeManager.getEarlySellTaxFor(seller);
    }
    
    /**
     * @dev See {IDOVE-isPaused} - delegated to admin manager
     */
    function isPaused() external view override returns (bool) {
        return adminManager.isPaused();
    }
    
    /**
     * @dev See {IDOVE-isMaxTxLimitEnabled} - delegated to admin manager
     */
    function isMaxTxLimitEnabled() external view override returns (bool) {
        return adminManager.isMaxTxLimitEnabled();
    }
    
    /**
     * @dev Calculates the effective amount that will be received after fees
     * @param sender Address sending the tokens
     * @param recipient Address receiving the tokens
     * @param amount Amount of tokens to be sent
     * @return The effective amount that would be received after fees
     */
    function getEffectiveTransferAmount(address sender, address recipient, uint256 amount) external view override returns (uint256) {
        // Skip fee calculation for excluded addresses or mint/burn
        if (amount == 0 || 
            feeManager.isExcludedFromFee(sender) || 
            feeManager.isExcludedFromFee(recipient) ||
            sender == address(0) ||
            recipient == address(0)) {
            return amount;
        }
        
        // Calculate fees
        (uint256 charityFeeAmount, uint256 earlySellTaxAmount) = feeManager.calculateFees(sender, recipient, amount);
        
        return amount - charityFeeAmount - earlySellTaxAmount;
    }
    
    // ================ Transfer Functions ================
    
    /**
     * @dev Override of the OpenZeppelin ERC20 _transfer function to include:
     * - Reentrancy protection with nonReentrant modifier
     * - Fee calculations and distribution
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override nonReentrant {
        // CHECKS - Guard clauses and state validation
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "ERC20: transfer amount must be greater than zero");
        
        // Cache external state values to prevent multiple calls
        bool isPaused = adminManager.isPaused();
        bool isMaxTxLimitEnabled = adminManager.isMaxTxLimitEnabled();
        bool isTokenLaunched = feeManager.isLaunched();
        bool isExcludedSender = feeManager.isExcludedFromFee(sender);
        bool isExcludedRecipient = feeManager.isExcludedFromFee(recipient);
        address charityWallet = feeManager.getCharityWallet();
        
        // Reject transfers when paused, unless the sender has the OPERATOR_ROLE
        if (isPaused) {
            require(hasRole(OPERATOR_ROLE, msg.sender), "ERC20Pausable: transfers paused and caller is not an operator");
        }
        
        // Check for max transaction limit if enabled
        if (isMaxTxLimitEnabled && !isExcludedSender && !isExcludedRecipient) {
            uint256 maxAmount;
            
            if (!isTokenLaunched) {
                // If token is not launched yet, use initial limit
                maxAmount = MAX_TX_INITIAL;
            } else {
                // Calculate time elapsed since launch
                uint256 timeElapsed = block.timestamp - feeManager.getLaunchTimestamp();
                
                // Apply time-based transaction limits
                if (timeElapsed < 24 hours) {
                    maxAmount = MAX_TX_INITIAL;
                } else {
                    maxAmount = MAX_TX_AFTER_24H;
                }
            }
            
            require(amount <= maxAmount, "DOVE: Transfer amount exceeds the maximum allowed");
        }
        
        // IMPORTANT: Calculate all fees before any state changes to follow CEI pattern
        (uint256 charityFeeAmount, uint256 earlySellTaxAmount) = feeManager.calculateFees(sender, recipient, amount);
        uint256 transferAmount = amount - charityFeeAmount - earlySellTaxAmount;
        
        // EFFECTS - Update the state
        super._transfer(sender, recipient, transferAmount);
        
        if (charityFeeAmount > 0) {
            super._transfer(sender, charityWallet, charityFeeAmount);
        }
        
        if (earlySellTaxAmount > 0) {
            super._burn(sender, earlySellTaxAmount);
        }
        
        // INTERACTIONS - Make external calls after state changes
        if (!isTokenLaunched) {
            // Set launch timestamp through fee manager
            feeManager._setLaunched(block.timestamp);
        }
        
        // Emit events after state changes but before external calls
        if (charityFeeAmount > 0) {
            emit CharityFeeCollected(charityFeeAmount);
        }
        
        if (earlySellTaxAmount > 0) {
            emit EarlySellTaxCollected(sender, earlySellTaxAmount);
        }
        
        // Update charity donation tracking
        if (charityFeeAmount > 0) {
            feeManager._addCharityDonation(charityFeeAmount);
        }
    }
}
