// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IDOVEFees.sol";
import "../utils/FeeCalculator.sol";
import "../access/MultiSigControl.sol";

/**
 * @title DOVE Fee Management
 * @dev Implementation of fee mechanisms for DOVE token (charity fee and early-sell tax)
 */
contract DOVEFees is Ownable2Step, ReentrancyGuard, IDOVEFees, MultiSigControl {
    // ================ Constants ================
    
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
    
    // Addresses for various wallets
    address public charityWallet;
    address private _tokenAddress;
    address private _tokenRegistrar;
    
    // Flag to track if token address has been verified
    bool private _isTokenAddressVerified;
    
    // Charity fee tracking
    uint256 private _totalCharityDonations;
    
    // Tax durations (configurable, but defaults to 24 hours for each tier)
    uint256 private _taxRateDayOne = 24 hours;
    uint256 private _taxRateDayTwo = 24 hours;
    uint256 private _taxRateDayThree = 24 hours;
    
    // Launch status
    bool private _isLaunched;
    
    // Early sell tax status (enabled by default)
    bool private _isEarlySellTaxEnabled = true;
    
    // Token address recovery
    address private _pendingTokenAddress;
    uint256 private _tokenRecoveryCompletionTime;
    
    // Fee exclusion mapping
    mapping(address => bool) private _isExcludedFromFee;
    
    // DEX address mapping
    mapping(address => bool) private _isKnownDex;
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor initializes the fee manager with charity wallet
     * @param charityWalletAddress Address to receive charity fees
     */
    constructor(address charityWalletAddress) MultiSigControl() {
        require(charityWalletAddress != address(0), "Charity wallet cannot be zero address");
        charityWallet = charityWalletAddress;
        
        // Exclude charity wallet from fees
        _isExcludedFromFee[charityWalletAddress] = true;
        
        // Set up initial roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FEE_MANAGER_ROLE, msg.sender);
        _setupRole(EMERGENCY_ADMIN_ROLE, msg.sender);
    }
    
    // ================ External View Functions ================
    
    /**
     * @dev Get the charity wallet address
     * @return Charity wallet address
     */
    function getCharityWallet() external view override returns (address) {
        return charityWallet;
    }
    
    /**
     * @dev Get the token address
     * @return Token contract address
     */
    function getTokenAddress() external view override returns (address) {
        return _tokenAddress;
    }
    
    /**
     * @dev Get the charity fee percentage (in basis points)
     * @return Charity fee in basis points
     */
    function getCharityFee() external pure override returns (uint16) {
        return FeeCalculator.CHARITY_FEE;
    }
    
    /**
     * @dev Get the launch timestamp
     * @return Launch timestamp, 0 if not launched
     */
    function getLaunchTimestamp() external view override returns (uint256) {
        return _launchTimestamp;
    }
    
    /**
     * @dev Check if token is launched
     * @return True if token is launched
     */
    function isLaunched() external view override returns (bool) {
        return _isLaunched;
    }
    
    /**
     * @dev Check if early sell tax is enabled
     * @return True if early sell tax is enabled
     */
    function isEarlySellTaxEnabled() external view override returns (bool) {
        return _isEarlySellTaxEnabled;
    }
    
    /**
     * @dev Get the total charity donations tracked
     * @return Total charity donations in wei
     */
    function getTotalCharityDonations() external view override returns (uint256) {
        return _totalCharityDonations;
    }
    
    /**
     * @dev Get the early sell tax rates
     * @return Day 1, Day 2, and Day 3 tax rates in basis points
     */
    function getTaxRates() external pure override returns (uint16, uint16, uint16) {
        return (FeeCalculator.TAX_RATE_DAY_1, FeeCalculator.TAX_RATE_DAY_2, FeeCalculator.TAX_RATE_DAY_3);
    }
    
    /**
     * @dev Get the early sell tax durations
     * @return Day 1, Day 2, and Day 3 durations in seconds
     */
    function getTaxDurations() external view override returns (uint256, uint256, uint256) {
        return (_taxRateDayOne, _taxRateDayTwo, _taxRateDayThree);
    }
    
    /**
     * @dev Calculate fees for a transfer
     * @param sender Address sending tokens
     * @param recipient Address receiving tokens
     * @param amount Amount being transferred
     * @return charityFeeAmount Charity fee amount
     * @return earlySellTaxAmount Early sell tax amount
     */
    function calculateFees(
        address sender,
        address recipient,
        uint256 amount
    ) external view override returns (uint256 charityFeeAmount, uint256 earlySellTaxAmount) {
        // Skip fee calculation if excluded addresses
        if (_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]) {
            return (0, 0);
        }
        
        // Calculate charity fee
        charityFeeAmount = FeeCalculator.calculateCharityFee(amount);
        
        // Calculate early sell tax (only on sells to DEX)
        if (_isEarlySellTaxEnabled && _isLaunched && _isKnownDex[recipient]) {
            // Calculate time elapsed since launch
            uint256 timeElapsed = block.timestamp - _launchTimestamp;
            
            // Calculate early sell tax
            earlySellTaxAmount = FeeCalculator.calculateEarlySellTaxByTime(
                amount,
                timeElapsed,
                _taxRateDayOne,
                _taxRateDayTwo,
                _taxRateDayThree
            );
        }
        
        return (charityFeeAmount, earlySellTaxAmount);
    }
    
    /**
     * @dev Calculate charity fee amount for a transfer
     * @param amount Amount of tokens being transferred
     * @return feeAmount Amount to be taken as fee
     */
    function calculateCharityFee(uint256 amount) external pure override returns (uint256) {
        return FeeCalculator.calculateCharityFee(amount);
    }
    
    /**
     * @dev Calculate early sell tax amount
     * @param amount Amount of tokens being sold
     * @param seller Address selling tokens
     * @param isDexSell Whether this is a sell to a DEX
     * @return taxAmount Amount to be taken as tax
     */
    function calculateEarlySellTax(
        uint256 amount,
        address seller,
        bool isDexSell
    ) external view override returns (uint256) {
        // Skip tax if not a DEX sell or if seller is excluded
        if (!isDexSell || _isExcludedFromFee[seller] || !_isEarlySellTaxEnabled || !_isLaunched) {
            return 0;
        }
        
        // Calculate time elapsed since launch
        uint256 timeElapsed = block.timestamp - _launchTimestamp;
        
        // Calculate tax amount
        return FeeCalculator.calculateEarlySellTaxByTime(
            amount,
            timeElapsed,
            _taxRateDayOne,
            _taxRateDayTwo,
            _taxRateDayThree
        );
    }
    
    /**
     * @dev Check if an address is a known DEX
     * @param addr Address to check
     * @return True if the address is a known DEX
     */
    function isKnownDex(address addr) external view override returns (bool) {
        return _isKnownDex[addr];
    }
    
    /**
     * @dev Check if an address is excluded from fees
     * @param addr Address to check
     * @return True if the address is excluded from fees
     */
    function isExcludedFromFee(address addr) external view override returns (bool) {
        return _isExcludedFromFee[addr];
    }
    
    /**
     * @dev Get the early sell tax rate for a specific seller
     * @param seller Address selling tokens
     * @return Tax rate in basis points
     */
    function getEarlySellTaxFor(address seller) external view override returns (uint16) {
        // Skip if seller is excluded or tax is disabled
        if (_isExcludedFromFee[seller] || !_isEarlySellTaxEnabled || !_isLaunched) {
            return 0;
        }
        
        // Calculate time elapsed since launch
        uint256 timeElapsed = block.timestamp - _launchTimestamp;
        
        // Get tax rate
        return FeeCalculator.getEarlySellTaxRate(
            timeElapsed,
            _taxRateDayOne,
            _taxRateDayTwo,
            _taxRateDayThree
        );
    }
    
    // ================ External Control Functions ================
    
    /**
     * @dev Set token address (can only be done once)
     * @param tokenAddress The address of the token contract
     */
    function setTokenAddress(address tokenAddress) external override {
        require(_tokenAddress == address(0), "Token address already set");
        require(tokenAddress != address(0), "Token address cannot be zero address");
        
        // Cache state variables to prevent redundant storage access
        _tokenAddress = tokenAddress;
        _tokenRegistrar = msg.sender;
        
        emit TokenAddressSet(tokenAddress);
    }
    
    /**
     * @dev Verify the token address with a confirmation code
     * @param confirmationCode Code provided during token registration
     */
    function verifyTokenAddress(bytes32 confirmationCode) external override nonReentrant {
        require(!_isTokenAddressVerified, "Token address already verified");
        require(msg.sender == _tokenAddress, "Only token can verify itself");
        
        // Verify confirmation code to ensure legitimate token contract
        bytes32 expectedCode = keccak256(abi.encodePacked("VERIFY_TOKEN_ADDRESS", _tokenAddress, block.chainid));
        require(confirmationCode == expectedCode, "Invalid confirmation code");
            
        // EFFECTS - Update state first before role assignment
        _isTokenAddressVerified = true;
        
        // Give the token contract the TOKEN_ROLE
        _setupRole(TOKEN_ROLE, _tokenAddress);
        
        emit TokenAddressVerified(_tokenAddress);
    }
    
    /**
     * @dev Set token as launched (called by token on first transfer)
     * @param launchTimestamp Timestamp when token launched
     */
    function _setLaunched(uint256 launchTimestamp) external override nonReentrant {
        require(msg.sender == _tokenAddress, "Only token contract can call");
        require(_isTokenAddressVerified, "Token address not verified");
        require(!_isLaunched, "Token already launched");
        
        // EFFECTS - Update state
        _isLaunched = true;
        _launchTimestamp = launchTimestamp;
        
        emit TokenLaunched(launchTimestamp);
    }
    
    /**
     * @dev Add charity donation to total tracked amount
     * @param amount Amount donated to charity
     */
    function _addCharityDonation(uint256 amount) external override nonReentrant {
        require(msg.sender == _tokenAddress, "Only token contract can call");
        require(_isTokenAddressVerified, "Token address not verified");
        
        // EFFECTS - Update state
        _totalCharityDonations += amount;
        
        emit CharityDonationAdded(amount, _totalCharityDonations);
    }
    
    /**
     * @dev Set excluded from fee status for an account (token only)
     * @param account Account to update
     * @param excluded Whether the account is excluded from fees
     */
    function _setExcludedFromFee(address account, bool excluded) external override {
        require(msg.sender == _tokenAddress, "Only token contract can call");
        require(_isTokenAddressVerified, "Token address not verified");
        
        _isExcludedFromFee[account] = excluded;
        
        emit ExcludedFromFeeUpdated(account, excluded);
    }
    
    /**
     * @dev Set a known DEX address (token only)
     * @param dexAddress The DEX address
     * @param isDex Whether the address is a DEX
     */
    function _setKnownDex(address dexAddress, bool isDex) external override {
        require(msg.sender == _tokenAddress, "Only token contract can call");
        require(_isTokenAddressVerified, "Token address not verified");
        
        _isKnownDex[dexAddress] = isDex;
        
        emit KnownDexUpdated(dexAddress, isDex);
    }
    
    /**
     * @dev Update the charity wallet address (token only)
     * @param newCharityWallet New charity wallet address
     */
    function _updateCharityWallet(address newCharityWallet) external override {
        require(msg.sender == _tokenAddress, "Only token contract can call");
        require(_isTokenAddressVerified, "Token address not verified");
        require(newCharityWallet != address(0), "Charity wallet cannot be zero address");
        
        charityWallet = newCharityWallet;
        
        // Exclude new charity wallet from fees
        _isExcludedFromFee[newCharityWallet] = true;
        
        emit CharityWalletUpdated(newCharityWallet);
    }
    
    /**
     * @dev Disable early sell tax permanently (token only)
     */
    function _disableEarlySellTax() external override {
        require(msg.sender == _tokenAddress, "Only token contract can call");
        require(_isTokenAddressVerified, "Token address not verified");
        require(_isEarlySellTaxEnabled, "Early sell tax already disabled");
        
        _isEarlySellTaxEnabled = false;
        
        emit EarlySellTaxDisabled();
    }
    
    // ================ Admin Functions ================
    
    /**
     * @dev Exclude an account from fees
     * @param account Address to exclude
     * @param excluded Whether to exclude the account
     */
    function setExcludedFromFee(address account, bool excluded) external onlyRole(FEE_MANAGER_ROLE) {
        _isExcludedFromFee[account] = excluded;
        
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
        
        charityWallet = newCharityWallet;
        
        // Exclude new charity wallet from fees
        _isExcludedFromFee[newCharityWallet] = true;
        
        emit CharityWalletUpdated(newCharityWallet);
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
}
