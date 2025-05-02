// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./DOVETransferHandler.sol";
import "../interfaces/IDOVE.sol";

/**
 * @title DOVE Token
 * @dev Implementation of the DOVE token with charity fee and early-sell tax mechanisms
 * This contract integrates all DOVE token modules into a cohesive system
 * 
 * IMPORTANT FEE STRUCTURE NOTICE:
 * This token implements two types of fees that affect transfer amounts:
 * 1. Charity Fee (0.5%): Applied to all transfers except excluded addresses
 *    - Fee is sent to a designated charity wallet
 * 2. Early Sell Tax (3% to 0%): Applied only when selling to DEX in first 72 hours
 *    - Tax rate decreases over time (5%, 3%, 1%, then 0%)
 *    - Tax amount is burned from supply
 * 
 * Users should be aware that the amount received by the recipient will be
 * less than the amount sent by the sender due to these fees.
 */
contract DOVE is DOVETransferHandler, IDOVE {
    /**
     * @dev Constructor initializes the DOVE token with references to managers
     * @param adminManagerAddress Address of the admin management contract
     * @param feeManagerAddress Address of the fee management contract
     */
    constructor(
        address adminManagerAddress,
        address feeManagerAddress
    ) DOVEBase("DOVE Token", "DOVE", adminManagerAddress, feeManagerAddress) {
        // Verify that owner of this contract controls the manager contracts
        // This prevents accidental misconfiguration
        address deployer = msg.sender;
        
        // SECURITY: Use direct ownership checks instead of transfers to avoid reentrancy
        // Check that the deployer is the owner of both manager contracts
        require(IDOVEAdmin(adminManagerAddress).owner() == deployer, "Deployer must own admin manager");
        require(IDOVEFees(feeManagerAddress).owner() == deployer, "Deployer must own fee manager");
        
        // Verify that fee manager has correct token role setup
        bytes32 tokenRole = IDOVEFees(feeManagerAddress).TOKEN_ROLE();
        require(!IDOVEFees(feeManagerAddress).hasRole(tokenRole, address(0)), "Token role not properly initialized");
        
        // Register this token contract with the fee manager using the secure verification mechanism
        IDOVEFees(feeManagerAddress).setTokenAddress(address(this));
        bytes32 confirmationCode = keccak256(abi.encodePacked("VERIFY_TOKEN_ADDRESS", address(this), block.chainid));
        IDOVEFees(feeManagerAddress).verifyTokenAddress(confirmationCode);
        
        // Set up access control roles - give deployer all roles to start
        _setupRole(DEFAULT_ADMIN_ROLE, deployer);
        _setupRole(PAUSER_ROLE, deployer);
        _setupRole(MINTER_ROLE, deployer);
        _setupRole(OPERATOR_ROLE, deployer);
        _setupRole(ROLE_MANAGER_ROLE, deployer);
        
        // Initial distribution: 100% to deployer, to be distributed according to tokenomics
        _mint(deployer, TOTAL_SUPPLY);
        
        // Token is deployed but not yet launched - this happens as a separate step
        // Initial set up complete
    }
    
    // ================ External View Functions ================
    
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
        // This is a stub - implement based on actual interface requirements
        // In the actual implementation, you would call a fee manager method
        return 0;
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
     * @dev Calculates the effective amount that will be received after applying fees
     * Useful for UI and user information purposes to show exact amounts
     * @param sender Address sending the tokens
     * @param recipient Address receiving the tokens
     * @param amount Amount of tokens to be sent
     * @return The effective amount that would be received after fees
     */
    function getEffectiveTransferAmount(address sender, address recipient, uint256 amount) external view override returns (uint256) {
        // Skip fee calculation if amount is zero, excluded addresses, or mint/burn
        if (amount == 0 || 
            feeManager.isExcludedFromFee(sender) || 
            feeManager.isExcludedFromFee(recipient) ||
            sender == address(0) ||
            recipient == address(0)) {
            return amount;
        }
        
        // Calculate fees using the internal function
        (uint256 charityFeeAmount, uint256 earlySellTaxAmount) = calculateFees(sender, recipient, amount);
        
        // Return the amount after deducting fees
        return amount - charityFeeAmount - earlySellTaxAmount;
    }
}
