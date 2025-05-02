// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IDOVE.sol";
import "./DOVEFees.sol";
import "./DOVEAdmin.sol";

/**
 * @title DOVE Token
 * @dev Implementation of the DOVE token with charity fee and early-sell tax mechanisms
 * 
 * IMPORTANT FEE STRUCTURE NOTICE:
 * This token implements two types of fees that affect transfer amounts:
 * 1. Charity Fee (0.5%): Applied to all transfers except excluded addresses
 *    - Fee is sent to a designated charity wallet
 * 2. Early Sell Tax (3% to 0%): Applied only when selling to DEX in first 72 hours
 *    - Tax rate decreases over time (3%, 2%, 1%, then 0%)
 *    - Tax amount is burned from supply
 * 
 * Users should be aware that the amount received by the recipient will be
 * less than the amount sent by the sender due to these fees.
 */
contract DOVE is ERC20Permit, ReentrancyGuard, IDOVE, AccessControl {
    
    // ================ Constants ================
    
    // Base supply: 100 billion tokens with 18 decimals
    uint256 private constant TOTAL_SUPPLY = 100_000_000_000 * 1e18;
    
    // Transaction limits
    uint256 private constant MAX_TX_INITIAL = TOTAL_SUPPLY * 2 / 1000; // 0.2%
    uint256 private constant MAX_TX_AFTER_24H = TOTAL_SUPPLY * 5 / 1000; // 0.5%
    
    // Charity fee percentage (0.5% = 50 basis points)
    uint16 private constant CHARITY_FEE = 50;
    
    // ================ Roles ================
    
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant ROLE_MANAGER_ROLE = keccak256("ROLE_MANAGER_ROLE");
    
    // Multi-signature role management
    uint256 private _requiredRoleApprovals = 3;  // Default: require 3 admins
    mapping(bytes32 => mapping(address => bool)) private _roleChangeApprovals;
    mapping(bytes32 => uint256) private _roleChangeApprovalCounts;
    
    // Role approval expiration - approvals automatically expire after this time
    uint256 private constant ROLE_APPROVAL_EXPIRATION = 3 days;
    mapping(bytes32 => uint256) private _roleChangeInitiatedTime;
    
    // ================ State Variables ================
    
    // Fee management module - handles charity fee and early sell tax
    DOVEFees public immutable feeManager;
    
    // Admin functionality module - handles owner controls
    DOVEAdmin public immutable adminManager;
    
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
        
        // Set up initial token supply (100 billion tokens)
        uint256 initialSupply = TOTAL_SUPPLY;
        
        // Initial distribution: 100% to deployer, to be distributed according to tokenomics
        _mint(msg.sender, initialSupply);
        
        // Set max transaction limit (1% of total supply)
        // This will be managed by the adminManager
        
        // Verify that owner of this contract controls the manager contracts
        // This prevents accidental misconfiguration
        DOVEAdmin adminManagerContract = DOVEAdmin(adminManagerAddress);
        DOVEFees feeManagerContract = DOVEFees(feeManagerAddress);
        
        // SECURITY: Use direct ownership checks instead of transfers to avoid reentrancy
        // Check that the deployer is the owner of both manager contracts
        require(adminManagerContract.owner() == msg.sender, "Deployer must own admin manager");
        require(feeManagerContract.owner() == msg.sender, "Deployer must own fee manager");
        
        // Verify that fee manager has correct token role setup
        bytes32 tokenRole = feeManagerContract.TOKEN_ROLE();
        require(!feeManagerContract.hasRole(tokenRole, address(0)), "Token role not properly initialized");
        
        // Register this token contract with the fee manager using the secure verification mechanism
        feeManagerContract.setTokenAddress(address(this));
        bytes32 confirmationCode = keccak256(abi.encodePacked("VERIFY_TOKEN_ADDRESS", address(this), block.chainid));
        feeManagerContract.verifyTokenAddress(confirmationCode);
        
        // Set up access control roles - give deployer all roles to start
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(OPERATOR_ROLE, msg.sender);
        _setupRole(ROLE_MANAGER_ROLE, msg.sender);
        
        // Token is deployed but not yet launched - this happens as a separate step
        
        // Initial set up complete
        emit Transfer(address(0), msg.sender, initialSupply);
    }
    
    // ================ External View Functions ================
    
    /**
     * @dev See {IDOVE-getMaxTransactionAmount}
     */
    function getMaxTransactionAmount() external view returns (uint256) {
        // Early check - if max tx limit is disabled, return max uint256
        if (!adminManager.isMaxTxLimitEnabled()) {
            return type(uint256).max;
        }
        
        // If token is not launched yet, use initial limit
        if (!feeManager.isLaunched()) {
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
    function getCharityFee() external view returns (uint16) {
        return feeManager.getCharityFee();
    }
    
    /**
     * @dev See {IDOVE-getCharityWallet} - delegated to fee manager
     */
    function getCharityWallet() external view returns (address) {
        return feeManager.getCharityWallet();
    }
    
    /**
     * @dev See {IDOVE-getLaunchTimestamp} - delegated to fee manager
     */
    function getLaunchTimestamp() external view returns (uint256) {
        return feeManager.getLaunchTimestamp();
    }
    
    /**
     * @dev See {IDOVE-getTotalCharityDonations} - delegated to fee manager
     */
    function getTotalCharityDonations() external view returns (uint256) {
        return feeManager.getTotalCharityDonations();
    }
    
    /**
     * @dev See {IDOVE-isLaunched} - delegated to fee manager
     */
    function isLaunched() external view returns (bool) {
        return feeManager.isLaunched();
    }
    
    /**
     * @dev See {IDOVE-isEarlySellTaxEnabled} - delegated to fee manager
     */
    function isEarlySellTaxEnabled() external view returns (bool) {
        return feeManager.isEarlySellTaxEnabled();
    }
    
    /**
     * @dev See {IDOVE-isExcludedFromFee} - delegated to fee manager
     */
    function isExcludedFromFee(address account) external view returns (bool) {
        return feeManager.isExcludedFromFee(account);
    }
    
    /**
     * @dev See {IDOVE-isKnownDex} - delegated to fee manager
     */
    function isKnownDex(address dexAddress) external view returns (bool) {
        return feeManager.isKnownDex(dexAddress);
    }
    
    /**
     * @dev See {IDOVE-getEarlySellTaxFor} - delegated to fee manager
     */
    function getEarlySellTaxFor(address seller) external view returns (uint16) {
        return feeManager.getEarlySellTaxFor(seller);
    }
    
    /**
     * @dev See {IDOVE-isPaused} - delegated to admin manager
     */
    function isPaused() external view returns (bool) {
        return adminManager.isPaused();
    }
    
    /**
     * @dev See {IDOVE-isMaxTxLimitEnabled} - delegated to admin manager
     */
    function isMaxTxLimitEnabled() external view returns (bool) {
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
    function getEffectiveTransferAmount(address sender, address recipient, uint256 amount) external view returns (uint256) {
        // Skip fee calculation if amount is zero, excluded addresses, or mint/burn
        if (amount == 0 || 
            feeManager.isExcludedFromFee(sender) || 
            feeManager.isExcludedFromFee(recipient) ||
            sender == address(0) ||
            recipient == address(0)) {
            return amount;
        }
        
        // Calculate applicable fees
        uint16 charityFeePercent = feeManager.getCharityFee();
        uint16 earlySellTaxPercent = 0;
        
        // Add early sell tax if applicable (only on sells to DEX)
        if (feeManager.isEarlySellTaxEnabled() && feeManager.isKnownDex(recipient)) {
            earlySellTaxPercent = feeManager.getEarlySellTaxFor(sender);
        }
        
        // Calculate total fee percentage and amount
        uint16 totalFeePercent = charityFeePercent + earlySellTaxPercent;
        
        if (totalFeePercent == 0) {
            return amount;
        }
        
        uint256 feeAmount = amount * totalFeePercent / 10000;
        return amount - feeAmount;
    }
    
    // ================ Internal Functions ================
    
    /**
     * @dev Update internal balances for a transfer
     * @param sender Address sending the tokens
     * @param recipient Address receiving the tokens
     * @param amount Amount of tokens to transfer
     * @notice SECURITY: This function is strictly internal with no external calls to prevent reentrancy
     * WARNING: Do not add external calls to this function or any functions it calls
     * WARNING: Do not override this function in derived contracts with external calls
     */
    function _update(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        // SECURITY: This function must not make any external calls to prevent reentrancy
        // All external interaction must happen before or after _update is called
        
        // Skip pointless zero transfers to save gas
        if (amount == 0) {
            return;
        }
        
        // SECURITY: Explicit balance check for underflow protection
        // Even though Solidity 0.8+ has built-in overflow checking, this makes the check explicit
        // and provides a more descriptive error message
        require(sender == address(0) || balanceOf(sender) >= amount, "ERC20: transfer amount exceeds balance");
        
        // Update sender balance
        if (sender != address(0)) {
            // Use proper _update method instead of direct balance manipulation
            super._update(sender, recipient, amount);
        } else {
            // If minting new tokens, use _update with address(0) as sender
            super._update(address(0), recipient, amount);
        }
        
        // Note: We don't need to update recipient balance here anymore
        // since super._update already handles this
        
        // Emit transfer event
        emit Transfer(sender, recipient, amount);
    }
    
    /**
     * @dev Override of the OpenZeppelin ERC20 _transfer function to include:
     * - Reentrancy protection with nonReentrant modifier
     * - Thorough application of checks-effects-interactions pattern
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
        require(balanceOf(sender) >= amount, "ERC20: transfer amount exceeds balance");
        
        // Reject transfers when paused, unless the sender has the OPERATOR_ROLE
        if (adminManager.paused()) {
            require(hasRole(OPERATOR_ROLE, msg.sender), "ERC20Pausable: transfers paused and caller is not an operator");
        }
        
        // Check for max transaction limit if enabled
        if (adminManager.isMaxTxLimitEnabled() && !feeManager.isExcludedFromFee(sender) && !feeManager.isExcludedFromFee(recipient)) {
            // Calculate max transaction amount inline since we can't call the public method from here
            uint256 maxAmount;
            
            // Early check - if max tx limit is disabled, use max uint256
            if (!adminManager.isMaxTxLimitEnabled()) {
                maxAmount = type(uint256).max;
            } else if (!feeManager.isLaunched()) {
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
        
        // ===== FEES CALCULATION - Load all state variables first =====
        
        // SECURITY: Load all necessary state variables for fee calculation into memory
        // before any state changes to avoid potential reentrancy or inconsistent state
        bool isExcludedSender = feeManager.isExcludedFromFee(sender);
        bool isExcludedRecipient = feeManager.isExcludedFromFee(recipient);
        bool isDexRecipient = feeManager.isKnownDex(recipient);
        address charityWallet = feeManager.charityWallet();
        
        // Calculate fees using pure function with no state changes
        (uint256 charityFeeAmount, uint256 earlySellTaxAmount) = feeManager.calculateFees(
            sender,
            recipient,
            amount
        );
        
        // Calculate final transfer amount after all fees
        uint256 transferAmount = amount - charityFeeAmount - earlySellTaxAmount;
        
        // ===== EFFECTS - Update all balances using the internal _update function =====
        
        // SECURITY: _update is a pure internal function with no external calls 
        // It only updates balances and emits events - it cannot reenter
        
        // First transfer the main amount to recipient
        _update(sender, recipient, transferAmount);
        
        // Then handle fees by transferring to respective wallets if applicable
        if (charityFeeAmount > 0) {
            _update(sender, charityWallet, charityFeeAmount);
        }
        
        if (earlySellTaxAmount > 0) {
            // Burn the early sell tax by transferring to address(0)
            _update(sender, address(0), earlySellTaxAmount);
        }
        
        // ===== INTERACTIONS - Only after all state changes are complete =====
        
        // SECURITY: All external calls come last, after all state changes
        
        // Update charity donation tracking
        if (charityFeeAmount > 0) {
            feeManager.addCharityDonation(charityFeeAmount);
        }
        
        // Update token acquisition timestamps for early-sell tax calculation
        if (transferAmount > 0 && !isExcludedRecipient && !isDexRecipient) {
            feeManager.updateAcquisitionTimestamp(recipient);
        }
    }
    
    /**
     * @dev Multi-signature requirement for granting roles
     * @param role The role to grant
     * @param account The account to grant the role to
     */
    function grantRole(bytes32 role, address account) public override nonReentrant {
        // Only role managers or admin role can grant roles
        require(hasRole(ROLE_MANAGER_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 
            "Must have role manager or admin role");
        
        // For the most sensitive roles, require multi-sig approval
        if (role == DEFAULT_ADMIN_ROLE || role == ROLE_MANAGER_ROLE) {
            bytes32 operation = keccak256(abi.encodePacked("grantRole", role, account));
            
            // Check if this is a new approval request
            if (_roleChangeApprovalCounts[operation] == 0) {
                // Initialize approval timestamp to enable timeout mechanism
                _roleChangeInitiatedTime[operation] = block.timestamp;
            }
            
            // Check if approval period has expired
            if (_roleChangeInitiatedTime[operation] > 0 && 
                block.timestamp > _roleChangeInitiatedTime[operation] + ROLE_APPROVAL_EXPIRATION) {
                // Reset approvals if expired
                _roleChangeApprovalCounts[operation] = 0;
                // Update timestamp for new approval period
                _roleChangeInitiatedTime[operation] = block.timestamp;
            }
            
            // If caller hasn't already approved, register their approval
            if (!_roleChangeApprovals[operation][msg.sender]) {
                _roleChangeApprovals[operation][msg.sender] = true;
                _roleChangeApprovalCounts[operation]++;
                
                emit RoleChangeApproved(role, account, msg.sender, _roleChangeApprovalCounts[operation], _requiredRoleApprovals);
            }
            
            // If we don't have enough approvals yet, revert
            if (_roleChangeApprovalCounts[operation] < _requiredRoleApprovals) {
                revert(string(abi.encodePacked("Role change requires ", 
                    toString(_requiredRoleApprovals - _roleChangeApprovalCounts[operation]), 
                    " more approvals")));
            }
            
            // Reset approvals after successful action to prevent reuse
            _roleChangeApprovalCounts[operation] = 0;
        }
        
        // Grant the role
        _grantRole(role, account);
    }
    
    /**
     * @dev Multi-signature requirement for revoking roles
     * @param role The role to revoke 
     * @param account The account to revoke the role from
     */
    function revokeRole(bytes32 role, address account) public override nonReentrant {
        // Only role managers or admin role can revoke roles
        require(hasRole(ROLE_MANAGER_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 
            "Must have role manager or admin role");
        
        // For the most sensitive roles, require multi-sig approval
        if (role == DEFAULT_ADMIN_ROLE || role == ROLE_MANAGER_ROLE) {
            bytes32 operation = keccak256(abi.encodePacked("revokeRole", role, account));
            
            // Check if this is a new approval request
            if (_roleChangeApprovalCounts[operation] == 0) {
                // Initialize approval timestamp to enable timeout mechanism
                _roleChangeInitiatedTime[operation] = block.timestamp;
            }
            
            // Check if approval period has expired
            if (_roleChangeInitiatedTime[operation] > 0 && 
                block.timestamp > _roleChangeInitiatedTime[operation] + ROLE_APPROVAL_EXPIRATION) {
                // Reset approvals if expired
                _roleChangeApprovalCounts[operation] = 0;
                // Update timestamp for new approval period
                _roleChangeInitiatedTime[operation] = block.timestamp;
            }
            
            // If caller hasn't already approved, register their approval
            if (!_roleChangeApprovals[operation][msg.sender]) {
                _roleChangeApprovals[operation][msg.sender] = true;
                _roleChangeApprovalCounts[operation]++;
                
                emit RoleChangeApproved(role, account, msg.sender, _roleChangeApprovalCounts[operation], _requiredRoleApprovals);
            }
            
            // If we don't have enough approvals yet, revert
            if (_roleChangeApprovalCounts[operation] < _requiredRoleApprovals) {
                revert(string(abi.encodePacked("Role change requires ", 
                    toString(_requiredRoleApprovals - _roleChangeApprovalCounts[operation]), 
                    " more approvals")));
            }
            
            // Reset approvals after successful action to prevent reuse
            _roleChangeApprovalCounts[operation] = 0;
        }
        
        // Revoke the role
        _revokeRole(role, account);
    }
    
    /**
     * @dev Helper function to convert uint to string for better error messages
     * @param value The uint to convert
     * @return string representation
     */
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        
        uint256 temp = value;
        uint256 digits;
        
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
    }
    
    // ================ Events ================
    event RoleChangeApproved(bytes32 indexed role, address indexed account, address indexed approver, uint256 currentApprovals, uint256 requiredApprovals);
    event RoleChangeAdded(bytes32 indexed operation, address indexed approver, bytes32 indexed role, address account, uint256 currentApprovals, uint256 requiredApprovals);
    event RoleChangeExecuted(bytes32 indexed operation, bytes32 indexed role, address account, uint256 approvalCount);
}
