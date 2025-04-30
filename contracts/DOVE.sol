// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./libraries/Reflection.sol";
import "./interfaces/IDOVE.sol";

/**
 * @title DOVE Token
 * @dev Implementation of the DOVE token with reflection tax mechanism and early-sell tax
 * Uses non-iterative reflection distribution for gas efficiency
 */
contract DOVE is ERC20Permit, Ownable2Step, Pausable, ReentrancyGuard, IDOVE {
    using Reflection for Reflection.ReflectionState;
    
    // ================ Constants ================
    
    // Base supply: 100 billion tokens with 18 decimals
    uint256 private constant TOTAL_SUPPLY = 100_000_000_000 * 1e18;
    
    // Reflection fee: 1% of transactions redistributed to holders
    uint16 private constant REFLECTION_FEE = 100; // 100 = 1.00%
    
    // Early sell tax rates (in basis points)
    uint16 private constant TAX_RATE_DAY_1 = 300; // 3% for first 24h
    uint16 private constant TAX_RATE_DAY_2 = 200; // 2% for 24-48h
    uint16 private constant TAX_RATE_DAY_3 = 100; // 1% for 48-72h
    
    // Transaction limits
    uint256 private constant MAX_TX_INITIAL = TOTAL_SUPPLY * 2 / 1000; // 0.2%
    uint256 private constant MAX_TX_AFTER_24H = TOTAL_SUPPLY * 5 / 1000; // 0.5%
    
    // ================ State Variables ================
    
    // Reflection mechanism state
    Reflection.ReflectionState private _reflectionState;
    
    // Timestamp of first transfer (launch time)
    uint256 private _launchTimestamp;
    
    // Flag to indicate if token is officially launched
    bool private _isLaunched = false;
    
    // Excluded from fee addresses
    mapping(address => bool) private _isExcludedFromFee;
    
    // Flags to control features
    bool private _isEarlySellTaxEnabled = true;
    bool private _isMaxTxLimitEnabled = true;
    
    // DEX identification for sell tax application
    mapping(address => bool) private _isKnownDex;
    
    // Configurable tax rate durations (in seconds)
    uint256 private _taxDurationDay1 = 1 days;
    uint256 private _taxDurationDay2 = 2 days;
    uint256 private _taxDurationDay3 = 3 days;
    
    // ================ Events ================
    
    event DexStatusUpdated(address indexed dexAddress, bool isMarkedAsDex);
    event TokenLaunched(uint256 timestamp);
    event ExcludeFromFee(address indexed account, bool excluded);
    event EarlySellTaxDisabled();
    event MaxTxLimitDisabled();
    event ReflectionFeeCollected(uint256 amount);
    event EarlySellTaxCollected(address indexed account, uint256 amount);
    event TaxDurationsUpdated(uint256 day1, uint256 day2, uint256 day3);
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor initializes the DOVE token and reflection mechanism
     */
    constructor() ERC20("DOVE", "DOVE") ERC20Permit("DOVE") Ownable(msg.sender) {
        // Initialize reflection state with total supply
        _reflectionState.initialize(TOTAL_SUPPLY);
        
        // Mint total supply to deployer
        _reflectionState.reflectionBalance[msg.sender] = _reflectionState.reflectionTotal;
        
        // Exclude owner and token contract from fees
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        
        // Emit initial transfer event (from zero address)
        emit Transfer(address(0), msg.sender, TOTAL_SUPPLY);
    }
    
    // ================ Public View Functions ================
    
    /**
     * @dev Override ERC20 balanceOf to use reflection-based balance
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _reflectionState.balanceOf(account);
    }
    
    /**
     * @dev Returns total supply (constant value)
     */
    function totalSupply() public pure override returns (uint256) {
        return TOTAL_SUPPLY;
    }
    
    /**
     * @dev See {IDOVE-getReflectionFee}
     */
    function getReflectionFee() external pure returns (uint16) {
        return REFLECTION_FEE;
    }
    
    /**
     * @dev See {IDOVE-getEarlySellTaxFor}
     */
    function getEarlySellTaxFor(address account) external view returns (uint16) {
        // No early-sell tax for excluded accounts or if disabled
        if (!_isEarlySellTaxEnabled || _isExcludedFromFee[account]) {
            return 0;
        }
        
        // If launch hasn't happened yet, return 0
        if (_launchTimestamp == 0) {
            return 0;
        }
        
        // Calculate time since launch
        uint256 timeSinceLaunch = block.timestamp - _launchTimestamp;
        
        // Apply different tax rates based on time since launch
        if (timeSinceLaunch < _taxDurationDay1) {
            return TAX_RATE_DAY_1;
        } else if (timeSinceLaunch < _taxDurationDay2) {
            return TAX_RATE_DAY_2;
        } else if (timeSinceLaunch < _taxDurationDay3) {
            return TAX_RATE_DAY_3;
        } else {
            return 0;
        }
    }
    
    /**
     * @dev See {IDOVE-isExcludedFromFee}
     */
    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcludedFromFee[account];
    }
    
    /**
     * @dev See {IDOVE-getMaxTransactionAmount}
     */
    function getMaxTransactionAmount() external view returns (uint256) {
        // If max tx limit is disabled, return max uint256
        if (!_isMaxTxLimitEnabled) {
            return type(uint256).max;
        }
        
        // If launch hasn't happened yet, return initial limit
        if (_launchTimestamp == 0) {
            return MAX_TX_INITIAL;
        }
        
        // After 24h, use increased limit
        if (block.timestamp - _launchTimestamp > 1 days) {
            return MAX_TX_AFTER_24H;
        } else {
            return MAX_TX_INITIAL;
        }
    }
    
    /**
     * @dev See {IDOVE-getLaunchTimestamp}
     */
    function getLaunchTimestamp() external view returns (uint256) {
        return _launchTimestamp;
    }
    
    /**
     * @dev Returns true if token has been officially launched
     * @return True if token is launched
     */
    function isLaunched() public view returns (bool) {
        return _isLaunched;
    }
    
    /**
     * @dev Returns true if the address is a known DEX (liquidity pool or router)
     * @param account Address to check
     * @return True if address is a known DEX
     */
    function isKnownDex(address account) public view returns (bool) {
        return _isKnownDex[account];
    }
    
    // ================ External Owner Functions ================
    
    /**
     * @dev See {IDOVE-excludeFromFee}
     * Can only be called by owner
     */
    function excludeFromFee(address account) external onlyOwner {
        require(!_isExcludedFromFee[account], "Account already excluded from fee");
        _isExcludedFromFee[account] = true;
        emit ExcludeFromFee(account, true);
    }
    
    /**
     * @dev See {IDOVE-includeInFee}
     * Can only be called by owner
     */
    function includeInFee(address account) external onlyOwner {
        require(_isExcludedFromFee[account], "Account already included in fee");
        _isExcludedFromFee[account] = false;
        emit ExcludeFromFee(account, false);
    }
    
    /**
     * @dev Exclude account from reflection mechanism
     * Can only be called by owner
     * @param account Address to exclude from reflections
     */
    function excludeFromReflection(address account) external onlyOwner {
        _reflectionState.excludeAccount(account);
    }
    
    /**
     * @dev Include previously excluded account in reflection mechanism
     * Can only be called by owner
     * @param account Address to include in reflections
     */
    function includeInReflection(address account) external onlyOwner {
        _reflectionState.includeAccount(account);
    }
    
    /**
     * @dev See {IDOVE-disableEarlySellTax}
     * Can only be called by owner
     * This action is irreversible
     */
    function disableEarlySellTax() external onlyOwner {
        require(_isEarlySellTaxEnabled, "Early sell tax already disabled");
        _isEarlySellTaxEnabled = false;
        emit EarlySellTaxDisabled();
    }
    
    /**
     * @dev See {IDOVE-disableMaxTxLimit}
     * Can only be called by owner
     * This action is irreversible
     */
    function disableMaxTxLimit() external onlyOwner {
        require(_isMaxTxLimitEnabled, "Max transaction limit already disabled");
        _isMaxTxLimitEnabled = false;
        emit MaxTxLimitDisabled();
    }
    
    /**
     * @dev Officially launches the token, enabling early-sell tax and transaction limits
     * Can only be called by owner
     * Can only be called once
     */
    function launch() external onlyOwner {
        require(!_isLaunched, "Token already launched");
        _isLaunched = true;
        _launchTimestamp = block.timestamp;
        emit TokenLaunched(_launchTimestamp);
    }
    
    /**
     * @dev Sets the DEX status of an address
     * Used to properly identify sell transactions for early-sell tax
     * Can only be called by owner
     * @param dexAddress Address to mark as DEX
     * @param isDex True to mark as DEX, false to remove DEX status
     */
    function setDexStatus(address dexAddress, bool isDex) external onlyOwner {
        require(dexAddress != address(0), "Cannot set zero address as DEX");
        _isKnownDex[dexAddress] = isDex;
        emit DexStatusUpdated(dexAddress, isDex);
    }
    
    /**
     * @dev Updates the durations for early-sell tax rates
     * Can only be called by owner
     * @param day1Duration Duration in seconds for first tax rate (TAX_RATE_DAY_1)
     * @param day2Duration Duration in seconds for second tax rate (TAX_RATE_DAY_2)
     * @param day3Duration Duration in seconds for third tax rate (TAX_RATE_DAY_3)
     */
    function updateTaxRateDurations(
        uint256 day1Duration,
        uint256 day2Duration,
        uint256 day3Duration
    ) external onlyOwner {
        require(day1Duration < day2Duration, "Day 1 duration must be less than Day 2");
        require(day2Duration < day3Duration, "Day 2 duration must be less than Day 3");
        
        _taxDurationDay1 = day1Duration;
        _taxDurationDay2 = day2Duration;
        _taxDurationDay3 = day3Duration;
        
        emit TaxDurationsUpdated(day1Duration, day2Duration, day3Duration);
    }
    
    /**
     * @dev Pause all token transfers
     * Can only be called by owner
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause all token transfers
     * Can only be called by owner
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // ================ Internal Functions ================
    
    /**
     * @dev Override _update function to apply reflection tax and transaction limits
     * @param from Sender address
     * @param to Recipient address
     * @param amount Amount of tokens to transfer
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused nonReentrant {
        // Skip all checks for zero transfers
        if (amount == 0) {
            super._update(from, to, 0);
            return;
        }
        
        // Set launch timestamp on first real transfer only if not explicitly launched
        // This is a fallback mechanism in case launch() wasn't called
        if (!_isLaunched && from != address(0) && to != address(0)) {
            _isLaunched = true;
            _launchTimestamp = block.timestamp;
            emit TokenLaunched(_launchTimestamp);
        }
        
        // Check max transaction limit
        if (_isMaxTxLimitEnabled &&
            from != address(0) && // Exclude minting
            to != address(0) &&   // Exclude burning
            !_isExcludedFromFee[from] && // Excluded addresses can exceed limit
            !_isExcludedFromFee[to]) {
            require(amount <= this.getMaxTransactionAmount(), "Transfer amount exceeds max transaction limit");
        }
        
        // Calculate fees
        uint16 totalFeePercent = 0;
        
        // Add reflection fee if applicable (excludes mint, burn, and excluded addresses)
        if (from != address(0) && to != address(0) && 
            !_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            totalFeePercent += REFLECTION_FEE;
        }
        
        // Add early sell tax if applicable (only applies to sells, not buys)
        // We identify "sells" as transfers to known liquidity pools or routers
        if (_isEarlySellTaxEnabled && 
            from != address(0) && 
            !_isExcludedFromFee[from] &&
            _isKnownDex[to]) {  // Check if recipient is a known DEX
            totalFeePercent += this.getEarlySellTaxFor(from);
        }
        
        // Execute transfer with reflection mechanism
        uint256 feeTaken = _reflectionState.transfer(from, to, amount, totalFeePercent);
        
        // Emit events
        if (totalFeePercent > 0) {
            // Extract reflection fee and early sell tax amounts
            uint256 reflectionFee = 0;
            uint256 earlySellTax = 0;
            
            if (!_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
                reflectionFee = amount * REFLECTION_FEE / 10000;
                earlySellTax = feeTaken - reflectionFee;
            } else {
                earlySellTax = feeTaken;
            }
            
            // Emit events for the fees taken
            if (reflectionFee > 0) {
                emit ReflectionFeeCollected(reflectionFee);
            }
            
            if (earlySellTax > 0) {
                emit EarlySellTaxCollected(from, earlySellTax);
            }
        }
        
        // Skip ERC20 bookkeeping since reflection handles balances
        emit Transfer(from, to, amount);
    }
}
