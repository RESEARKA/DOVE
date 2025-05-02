// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IDOVEFees.sol";

/**
 * @title DOVE Fee Base
 * @dev Base contract for DOVE fee management - core functionality and state variables
 */
abstract contract DOVEFeeBase is Ownable2Step, AccessControl, ReentrancyGuard {
    // ================ Constants ================
    
    // Basis points (100% = 10000 basis points)
    uint16 internal constant BASIS_POINTS = 10000;
    
    // Charity fee: 0.5% of transactions sent to charity wallet
    uint16 internal constant CHARITY_FEE = 50; // 50 = 0.50%
    
    // Early sell tax rates (in basis points)
    uint16 internal constant TAX_RATE_DAY_1 = 500; // 5.00% (500 basis points)
    uint16 internal constant TAX_RATE_DAY_2 = 300; // 3.00% (300 basis points)
    uint16 internal constant TAX_RATE_DAY_3 = 100; // 1.00% (100 basis points)
    
    // Tax duration constraints
    uint256 internal constant MIN_TAX_DURATION = 6 hours;
    uint256 internal constant MAX_TAX_DURATION = 7 days;
    uint256 internal constant MAX_TOTAL_TAX_DURATION = 14 days;
    
    // Time-lock for token address changes
    uint256 internal constant TOKEN_ADDRESS_TIMELOCK = 24 hours;
    
    // ================ Role Definitions ================
    
    // Role for token contract
    bytes32 public constant TOKEN_ROLE = keccak256("TOKEN_ROLE");
    
    // Role for fee managers (can configure fees and tax rates)
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");
    
    // Role for emergency admins (can disable early sell tax)
    bytes32 public constant EMERGENCY_ADMIN_ROLE = keccak256("EMERGENCY_ADMIN_ROLE");
    
    // ================ State Variables ================
    
    // Timestamp of first transfer (launch time)
    uint256 internal _launchTimestamp;
    
    // Addresses for various wallets
    address internal _charityWallet;
    address internal _tokenAddress;
    address internal _tokenRegistrar;
    
    // Flag to track if token address has been verified
    bool internal _isTokenAddressVerified;
    
    // Charity fee tracking
    uint256 internal _totalCharityDonations;
    
    // Tax durations (configurable, but defaults to 24 hours for each tier)
    uint256 internal _taxRateDayOne = 24 hours;
    uint256 internal _taxRateDayTwo = 24 hours;
    uint256 internal _taxRateDayThree = 24 hours;
    
    // Launch status
    bool internal _isLaunched;
    
    // Early sell tax status (enabled by default)
    bool internal _isEarlySellTaxEnabled = true;
    
    // Token address recovery
    address internal _pendingTokenAddress;
    uint256 internal _tokenRecoveryCompletionTime;
    
    // Fee exclusion mapping
    mapping(address => bool) internal _isExcludedFromFee;
    
    // DEX address mapping
    mapping(address => bool) internal _isKnownDex;
    
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
}
