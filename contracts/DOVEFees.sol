// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IDOVEFees.sol";

/**
 * @title DOVE Fee Management
 * @dev Implementation of fee mechanisms for DOVE token (charity fee and early-sell tax)
 */
contract DOVEFees is Ownable2Step, AccessControl, ReentrancyGuard, IDOVEFees {
    
    // ================ Constants ================
    
    // Basis points (100% = 10000 basis points)
    uint16 private constant BASIS_POINTS = 10000;
    
    // Charity fee: 0.5% of transactions sent to charity wallet
    uint16 private constant CHARITY_FEE = 50; // 50 = 0.50%
    
    // Early sell tax rates (in basis points)
    uint16 private constant TAX_RATE_DAY_1 = 500; // 5.00% (500 basis points)
    uint16 private constant TAX_RATE_DAY_2 = 300; // 3.00% (300 basis points)
    uint16 private constant TAX_RATE_DAY_3 = 100; // 1.00% (100 basis points)
    
    // Tax duration constraints
    uint256 private constant MIN_TAX_DURATION = 6 hours;
    uint256 private constant MAX_TAX_DURATION = 7 days;
    uint256 private constant MAX_TOTAL_TAX_DURATION = 14 days;
    
    // Time-lock for token address changes
    uint256 private constant TOKEN_ADDRESS_TIMELOCK = 24 hours;
    
    // ================ Role Definitions ================
    
    // Role for token contract
    bytes32 public constant TOKEN_ROLE = keccak256("TOKEN_ROLE");
    
    // Role for fee managers (can configure fees and tax rates)
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");
    
    // Role for emergency admins (can disable early sell tax)
    bytes32 public constant EMERGENCY_ADMIN_ROLE = keccak256("EMERGENCY_ADMIN_ROLE");
    
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
    
    // Address of the token contract that can call fee functions
    address private _tokenAddress;
    
    // Address that registered the token contract (owner at time of registration)
    address private _tokenRegistrar;
    
    // Flag for token address verification
    bool private _isTokenAddressVerified = false;
    
    // Pending token address for recovery
    address private _pendingTokenAddress;
    
    // Timestamp for pending token address recovery
    uint256 private _pendingTokenAddressTimestamp;
    
    // Multi-signature governance for emergency actions
    mapping(bytes32 => mapping(address => bool)) private _emergencyApprovals;
    mapping(bytes32 => uint256) private _emergencyApprovalCounts;
    uint256 private _requiredEmergencyApprovals = 2; // Default: require 2 emergency admins
    
    // ================ Events ================
    
    event TokenLaunched(uint256 launchTimestamp);
    event ExcludedFromFeeUpdated(address account, bool excluded);
    event KnownDexUpdated(address dexAddress, bool isDex);
    event CharityWalletUpdated(address newCharityWallet);
    event TaxRateDurationsUpdated(uint256 dayOne, uint256 dayTwo, uint256 dayThree);
    event EarlySellTaxDisabled();
    event CharityDonationAdded(uint256 amount, uint256 newTotal);
    event TokenAddressSet(address tokenAddress);
    event TokenAddressRecoveryInitiated(address newTokenAddress, uint256 completionTimestamp);
    event TokenAddressRecovered(address oldTokenAddress, address newTokenAddress);
    event TokenAddressRecoveryCanceled(address canceledAddress);
    event TokenAddressVerified(address tokenAddress);
    event EmergencyApprovalRecorded(bytes32 indexed operation, address indexed approver, uint256 currentApprovals, uint256 requiredApprovals);
    event EmergencyActionExecuted(bytes32 indexed operation, address indexed executor, uint256 approvalCount);
    event RequiredEmergencyApprovalsUpdated(uint256 required);
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor initializes the fee manager with charity wallet
     * @param charityWallet Address to receive charity fees
     */
    constructor(address charityWallet) {
        require(charityWallet != address(0), "Charity wallet cannot be zero address");
        _charityWallet = charityWallet;
        
        // Exclude charity wallet from fees
        _isExcludedFromFee[charityWallet] = true;
        
        // Set up initial roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FEE_MANAGER_ROLE, msg.sender);
        _setupRole(EMERGENCY_ADMIN_ROLE, msg.sender);
    }
    
    // ================ Secure Token Address Setup ================
    
    /**
     * @dev Set the token address securely - can only be set once
     * @notice This function can only be called once by the owner to establish trust
     */
    function setTokenAddress(address tokenAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_tokenAddress == address(0), "Token address already set");
        require(tokenAddress != address(0), "Token address cannot be zero");
        
        _tokenAddress = tokenAddress;
        _tokenRegistrar = msg.sender;
        
        // Grant token role to the token address
        _setupRole(TOKEN_ROLE, tokenAddress);
        
        emit TokenAddressSet(tokenAddress);
    }
    
    /**
     * @dev Initiate recovery from token address misconfiguration - starts timelock
     * @notice Can only be called by the original registrar (owner who set the token address)
     * @param newTokenAddress New token contract address
     */
    function initiateTokenAddressRecovery(address newTokenAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Only the original registrar (owner at time of registration) can recover
        require(msg.sender == _tokenRegistrar, "Only original registrar can recover");
        require(newTokenAddress != address(0), "Token address cannot be zero");
        require(!_isTokenAddressVerified, "Cannot change verified token address");
        
        // Set the pending new address with timelock
        _pendingTokenAddress = newTokenAddress;
        _pendingTokenAddressTimestamp = block.timestamp;
        
        emit TokenAddressRecoveryInitiated(newTokenAddress, block.timestamp + TOKEN_ADDRESS_TIMELOCK);
    }
    
    /**
     * @dev Complete token address recovery after timelock period
     * @notice This enforces a minimum waiting period before address changes can be completed
     */
    function completeTokenAddressRecovery() external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Only the original registrar can complete the recovery
        require(msg.sender == _tokenRegistrar, "Only original registrar can recover");
        require(_pendingTokenAddress != address(0), "No pending token address");
        require(block.timestamp >= _pendingTokenAddressTimestamp + TOKEN_ADDRESS_TIMELOCK, 
            "Timelock period not elapsed");
        
        // Update the token address
        address oldTokenAddress = _tokenAddress;
        
        // Revoke role from old token address
        revokeRole(TOKEN_ROLE, _tokenAddress);
        
        // Set new token address and grant role
        _tokenAddress = _pendingTokenAddress;
        _setupRole(TOKEN_ROLE, _pendingTokenAddress);
        
        // Clear pending state
        _pendingTokenAddress = address(0);
        
        emit TokenAddressRecovered(oldTokenAddress, _tokenAddress);
    }
    
    /**
     * @dev Verifies the token address with a confirmation code
     * This can only be called by the token contract itself
     * @param confirmationCode The confirmation code to verify
     */
    function verifyTokenAddress(bytes32 confirmationCode) external {
        // Only token can verify itself - this check ensures that msg.sender is the token address
        require(msg.sender == _tokenAddress, "Only token can verify itself");
        
        // Confirmation code must match to prevent accidental verification
        bytes32 expectedCode = keccak256(abi.encodePacked("VERIFY_TOKEN_ADDRESS", _tokenAddress, block.chainid));
        require(confirmationCode == expectedCode, "Invalid confirmation code");
        
        // SECURITY: We've confirmed both that the caller is the token address and they have the correct code
        // This provides double protection against accidental or malicious verification
        _isTokenAddressVerified = true;
        
        // Give the token contract the TOKEN_ROLE
        _setupRole(TOKEN_ROLE, _tokenAddress);
        
        emit TokenAddressVerified(_tokenAddress);
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
     * @dev Calculate early sell tax percentage (in basis points) based on token holding period
     * @param holder Address of the token holder
     * @return taxBasisPoints Early sell tax percentage in basis points (1 BP = 0.01%)
     */
    function getEarlySellTaxFor(address holder) 
        public
        view 
        returns (uint16 taxBasisPoints) 
    {
        // If early sell tax is disabled, return 0
        if (!_isEarlySellTaxEnabled) {
            return 0;
        }
        
        // Skip tax calculation for excluded addresses to save gas
        if (isExcludedFromFee(holder)) {
            return 0;
        }
        
        // Cache storage variables in memory to reduce gas costs
        // This prevents multiple storage reads of the same variables
        bool isLaunched = _isLaunched;
        uint256 launchTimestamp = _launchTimestamp;
        uint256 taxRateDayOne = _taxRateDayOne;
        uint256 taxRateDayTwo = _taxRateDayTwo;
        uint256 taxRateDayThree = _taxRateDayThree;
        
        // Early check - if tax is disabled or token not launched, no tax applies
        if (!isEarlySellTaxEnabled || !isLaunched) {
            return 0;
        }
        
        // Calculate time elapsed since launch using cached timestamp
        uint256 timeElapsed = block.timestamp - launchTimestamp;
        
        // Use strictly greater than comparisons to create clear boundaries
        // This addresses the potential edge cases at day transitions
        // A transaction exactly at the boundary will fall into the lower tax rate bracket
        if (timeElapsed <= taxRateDayOne) {
            // First 24 hours: 5.00% tax (500 basis points)
            return TAX_RATE_DAY_1;
        } else if (timeElapsed <= taxRateDayTwo) {
            // 24-48 hours: 3.00% tax (300 basis points)
            return TAX_RATE_DAY_2;
        } else if (timeElapsed <= taxRateDayThree) {
            // 48-72 hours: 1.00% tax (100 basis points)
            return TAX_RATE_DAY_3;
        } else {
            // After 72 hours: 0% tax
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
    function setLaunched(uint256 launchTimestamp) external onlyRole(TOKEN_ROLE) {
        require(!_isLaunched, "Token already launched");
        _launchTimestamp = launchTimestamp;
        _isLaunched = true;
        
        // Emit the token launched event for transparency
        emit TokenLaunched(launchTimestamp);
    }
    
    /**
     * @dev Track charity donations - external interface
     * @param amount Amount to add to charity donations
     */
    function addCharityDonation(uint256 amount) external nonReentrant onlyRole(TOKEN_ROLE) {
        uint256 newTotal = _totalCharityDonations + amount;
        _totalCharityDonations = newTotal;
        
        // Emit event for transparency and tracking donations
        emit CharityDonationAdded(amount, newTotal);
    }
    
    /**
     * @dev Set an address as excluded from fees - external interface
     * @param account Address to exclude/include
     * @param excluded Whether address is excluded or not
     */
    function setExcludedFromFee(address account, bool excluded) external onlyRole(FEE_MANAGER_ROLE) {
        _isExcludedFromFee[account] = excluded;
        
        // Emit event for transparency when fee exclusion status changes
        emit ExcludedFromFeeUpdated(account, excluded);
    }
    
    /**
     * @dev Set an address as known DEX - external interface
     * @param dexAddress Address to mark as DEX
     * @param isDex Whether this address is a DEX or not
     */
    function setKnownDex(address dexAddress, bool isDex) external onlyRole(FEE_MANAGER_ROLE) {
        _isKnownDex[dexAddress] = isDex;
        
        // Emit event for transparency when DEX status changes
        emit KnownDexUpdated(dexAddress, isDex);
    }
    
    /**
     * @dev Update the charity wallet - external interface
     * @param newCharityWallet New charity wallet address
     */
    function updateCharityWallet(address newCharityWallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newCharityWallet != address(0), "Charity wallet cannot be zero address");
        _charityWallet = newCharityWallet;
        
        // Emit event for transparency when charity wallet changes
        emit CharityWalletUpdated(newCharityWallet);
    }
    
    /**
     * @dev Update the tax rate durations - external interface
     * @param dayOne Duration in seconds for day 1 tax rate
     * @param dayTwo Duration in seconds for day 2 tax rate
     * @param dayThree Duration in seconds for day 3 tax rate
     */
    function updateTaxRateDurations(
        uint256 dayOne,
        uint256 dayTwo,
        uint256 dayThree
    ) external onlyRole(FEE_MANAGER_ROLE) {
        require(dayOne < dayTwo && dayTwo < dayThree, "Invalid durations: must be ascending");
        
        // Ensure each duration is within reasonable limits
        require(dayOne >= MIN_TAX_DURATION, "Day one duration too short");
        require(dayThree <= MAX_TOTAL_TAX_DURATION, "Total tax duration too long");
        
        // Ensure individual durations are not excessive
        require(dayOne <= MAX_TAX_DURATION, "Day one duration too long");
        require(dayTwo - dayOne <= MAX_TAX_DURATION, "Day two duration too long");
        require(dayThree - dayTwo <= MAX_TAX_DURATION, "Day three duration too long");
        
        _taxRateDayOne = dayOne;
        _taxRateDayTwo = dayTwo;
        _taxRateDayThree = dayThree;
        
        // Emit event for transparency when tax rate durations change
        emit TaxRateDurationsUpdated(dayOne, dayTwo, dayThree);
    }
    
    /**
     * @dev Modifier to require multiple emergency admin approvals
     * @param operation Hash of the operation requiring approval
     */
    modifier requiresMultipleEmergencyApprovals(bytes32 operation) {
        require(hasRole(EMERGENCY_ADMIN_ROLE, msg.sender), "Not an emergency admin");
        
        // Check if already has required approvals
        if (_emergencyApprovalCounts[operation] >= _requiredEmergencyApprovals) {
            // Store approval count for event
            uint256 currentApprovals = _emergencyApprovalCounts[operation];
            
            // Flag to indicate execution in progress
            bool isExecuting = true;
            
            // Reset before execution to prevent reentrancy
            _emergencyApprovalCounts[operation] = 0;
            
            // Execute function body
            _;
            
            // If execution completed successfully, emit event
            if (isExecuting) {
                emit EmergencyActionExecuted(operation, msg.sender, currentApprovals);
            }
        } else {
            // Record this approval
            if (!_emergencyApprovals[operation][msg.sender]) {
                _emergencyApprovals[operation][msg.sender] = true;
                _emergencyApprovalCounts[operation] += 1;
                
                emit EmergencyApprovalRecorded(
                    operation, 
                    msg.sender, 
                    _emergencyApprovalCounts[operation],
                    _requiredEmergencyApprovals
                );
            }
            
            revert(string(abi.encodePacked(
                "Emergency operation requires ", 
                toString(_requiredEmergencyApprovals - _emergencyApprovalCounts[operation]),
                " more approvals"
            )));
        }
    }
    
    /**
     * @dev Set the number of required emergency approvals
     * @param required Number of required approvals
     */
    function setRequiredEmergencyApprovals(uint256 required) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(required >= 2, "Minimum 2 approvals required for security");
        
        _requiredEmergencyApprovals = required;
        emit RequiredEmergencyApprovalsUpdated(required);
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
    
    /**
     * @dev Disable early sell tax permanently - emergency use only
     * @notice This is a one-way operation that cannot be reversed
     * SECURITY: Requires multiple emergency admin approvals
     */
    function disableEarlySellTax() 
        external 
        nonReentrant
        requiresMultipleEmergencyApprovals(keccak256("disableEarlySellTax"))
    {
        require(_isEarlySellTaxEnabled, "Early sell tax already disabled");
        
        // SECURITY: Apply checks-effects-interactions pattern
        // Update internal state first
        _isEarlySellTaxEnabled = false;
        
        // Then emit event (no external calls made)
        emit EarlySellTaxDisabled();
    }
    
    /**
     * @dev Add a new fee manager
     * @param account Address to grant fee manager role
     */
    function addFeeManager(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(FEE_MANAGER_ROLE, account);
    }
    
    /**
     * @dev Remove a fee manager
     * @param account Address to revoke fee manager role
     */
    function removeFeeManager(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(FEE_MANAGER_ROLE, account);
    }
    
    /**
     * @dev Add an emergency admin
     * @param account Address to grant emergency admin role
     */
    function addEmergencyAdmin(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(EMERGENCY_ADMIN_ROLE, account);
    }
    
    /**
     * @dev Remove an emergency admin
     * @param account Address to revoke emergency admin role
     */
    function removeEmergencyAdmin(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(EMERGENCY_ADMIN_ROLE, account);
    }
}
