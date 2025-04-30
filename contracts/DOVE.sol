// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IDOVE.sol";

/**
 * @title DOVE Token
 * @dev Implementation of the DOVE token with charity fee and early-sell tax mechanisms
 */
contract DOVE is ERC20Permit, Ownable2Step, Pausable, ReentrancyGuard, IDOVE {
    
    // ================ Constants ================
    
    // Base supply: 100 billion tokens with 18 decimals
    uint256 private constant TOTAL_SUPPLY = 100_000_000_000 * 1e18;
    
    // Charity fee: 0.5% of transactions sent to charity wallet
    uint16 private constant CHARITY_FEE = 50; // 50 = 0.50%
    
    // Early sell tax rates (in basis points)
    uint16 private constant TAX_RATE_DAY_1 = 300; // 3% for first 24h
    uint16 private constant TAX_RATE_DAY_2 = 200; // 2% for 24-48h
    uint16 private constant TAX_RATE_DAY_3 = 100; // 1% for 48-72h
    
    // Transaction limits
    uint256 private constant MAX_TX_INITIAL = TOTAL_SUPPLY * 2 / 1000; // 0.2%
    uint256 private constant MAX_TX_AFTER_24H = TOTAL_SUPPLY * 5 / 1000; // 0.5%
    
    // ================ State Variables ================
    
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
    
    // Charity wallet to receive fee
    address private _charityWallet;
    
    // Total accumulated charity donations
    uint256 private _totalCharityDonations;
    
    // ================ Events ================
    
    event DexStatusUpdated(address indexed dexAddress, bool isMarkedAsDex);
    event TokenLaunched(uint256 timestamp);
    event TaxDurationsUpdated(uint256 day1, uint256 day2, uint256 day3);
    event CharityFeeCollected(uint256 amount);
    event EarlySellTaxCollected(address indexed account, uint256 amount);
    event CharityWalletUpdated(address indexed oldWallet, address indexed newWallet);
    event ExcludeFromFee(address indexed account, bool excluded);
    event EarlySellTaxDisabled();
    event MaxTxLimitDisabled();
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor initializes the DOVE token
     * @param initialCharityWallet Address to receive charity fees
     */
    constructor(address initialCharityWallet) ERC20("DOVE", "DOVE") ERC20Permit("DOVE") Ownable(msg.sender) {
        require(initialCharityWallet != address(0), "Charity wallet cannot be zero address");
        
        // Set charity wallet
        _charityWallet = initialCharityWallet;
        
        // Mint total supply to deployer
        _mint(msg.sender, TOTAL_SUPPLY);
        
        // Exclude owner, token contract, and charity wallet from fees
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[initialCharityWallet] = true;
    }
    
    // ================ Public View Functions ================
    
    /**
     * @dev Returns the current charity fee percentage
     * @return Fee percentage where 100 = 1%
     */
    function getCharityFee() external pure returns (uint16) {
        return CHARITY_FEE;
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
    
    /**
     * @dev Returns the address of the charity wallet
     * @return Address of the charity wallet
     */
    function getCharityWallet() external view returns (address) {
        return _charityWallet;
    }
    
    /**
     * @dev Returns the total amount of tokens donated to charity
     * @return Total amount donated
     */
    function getTotalCharityDonations() external view returns (uint256) {
        return _totalCharityDonations;
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
     * @dev Updates the charity wallet address
     * Can only be called by owner
     * @param newCharityWallet New address to receive charity fees
     */
    function setCharityWallet(address newCharityWallet) external onlyOwner {
        require(newCharityWallet != address(0), "New charity wallet cannot be zero address");
        address oldCharityWallet = _charityWallet;
        _charityWallet = newCharityWallet;
        
        // Exclude new charity wallet from fees
        _isExcludedFromFee[newCharityWallet] = true;
        
        emit CharityWalletUpdated(oldCharityWallet, newCharityWallet);
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
    
    // ================ Internal Functions ================
    
    /**
     * @dev Override _update function to apply charity fee and transaction limits
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
        
        // Cache address checks to avoid redundant operations
        bool isMint = from == address(0);
        bool isBurn = to == address(0);
        bool isRealTransfer = !isMint && !isBurn;
        bool isSenderExcluded = _isExcludedFromFee[from];
        bool isReceiverExcluded = _isExcludedFromFee[to];
        bool isSellToKnownDex = _isKnownDex[to];
        
        // Set launch timestamp on first real transfer only if not explicitly launched
        // This is a fallback mechanism in case launch() wasn't called
        if (!_isLaunched && isRealTransfer) {
            _isLaunched = true;
            _launchTimestamp = block.timestamp;
            emit TokenLaunched(_launchTimestamp);
        }
        
        // Check max transaction limit
        if (_isMaxTxLimitEnabled && 
            isRealTransfer && 
            !isSenderExcluded && 
            !isReceiverExcluded) {
            require(amount <= this.getMaxTransactionAmount(), "Transfer amount exceeds max transaction limit");
        }
        
        // Calculate fees - clearly separate different fee types for better tracking
        uint16 charityFeePercent = 0;
        uint16 earlySellTaxPercent = 0;
        
        // Apply charity fee if applicable (excludes mint, burn, and excluded addresses)
        if (isRealTransfer && !isSenderExcluded && !isReceiverExcluded) {
            charityFeePercent = CHARITY_FEE;
        }
        
        // Add early sell tax if applicable (only applies to sells to DEX addresses)
        if (_isEarlySellTaxEnabled && !isMint && !isSenderExcluded && isSellToKnownDex) {
            earlySellTaxPercent = this.getEarlySellTaxFor(from);
        }
        
        // Total fee percentage is the sum of both fee types
        uint16 totalFeePercent = charityFeePercent + earlySellTaxPercent;
        
        // Process the transfer with fees if applicable
        if (totalFeePercent > 0) {
            // For small fee percentages (≤1%), divide first to prevent overflow
            uint256 feeAmount;
            if (totalFeePercent <= 100) {
                feeAmount = amount / 10000 * totalFeePercent;
            } else {
                // For larger percentages, calculate normally
                feeAmount = amount * totalFeePercent / 10000;
            }
            
            // Transfer amount after deducting fees
            uint256 transferAmount = amount - feeAmount;
            
            // Calculate exact amount for each fee type based on percentages
            uint256 charityFee = 0;
            uint256 earlySellTax = 0;
            
            if (totalFeePercent > 0) {
                // Calculate each fee proportionally to avoid rounding errors
                charityFee = feeAmount * charityFeePercent / totalFeePercent;
                earlySellTax = feeAmount - charityFee;
            }
            
            // Process ERC20 transfers
            super._update(from, to, transferAmount);
            
            // Send charity fee to charity wallet if applicable
            if (charityFee > 0) {
                super._update(from, _charityWallet, charityFee);
                _totalCharityDonations += charityFee;
                emit CharityFeeCollected(charityFee);
            }
            
            // Early sell tax is automatically burned
            if (earlySellTax > 0) {
                super._update(from, address(0), earlySellTax); // Burn early sell tax
                emit EarlySellTaxCollected(from, earlySellTax);
            }
        } else {
            // No fees, do regular transfer
            super._update(from, to, amount);
        }
    }
}
