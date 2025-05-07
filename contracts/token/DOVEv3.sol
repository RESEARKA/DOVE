// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../errors/DOVEErrors.sol";
import "../interfaces/IDOVE.sol";
import "../interfaces/IDOVEInfo.sol";
import "../token/DOVEEvents.sol";
import "../liquidity/DOVELiquidityManager.sol";

/**
 * @title DOVEv3
 * @dev ERC20 token with tapering early-sell tax and auto-LP mechanics using Uniswap V3
 */
contract DOVEv3 is ERC20, Ownable, Pausable, ReentrancyGuard, IDOVE, IDOVEInfo {
    using SafeERC20 for IERC20;

    // ========== STATE VARIABLES ==========
    
    // Total token supply: 100 billion tokens with 18 decimals
    uint256 public constant MAX_SUPPLY = 100_000_000_000 * 10**18;
    
    // Fee constants
    uint256 public constant MAX_FEE = 500; // 5% (in basis points)
    uint256 public constant CHARITY_FEE = 50; // 0.5% (in basis points)
    
    // Early sell tax structure
    uint256 public constant DAYS_TO_ZERO_TAX = 7; // Number of days until tax is zero
    uint256 public constant INITIAL_SELL_TAX = 300; // 3% (in basis points)
    
    // Token launch timestamp
    uint256 public immutable launchTimestamp;
    
    // Liquidity manager contract
    DOVELiquidityManager public liquidityManager;
    
    // Address to receive charity fees
    address public charityWallet;
    
    // Addresses exempt from fees
    mapping(address => bool) public isExemptFromFees;
    
    // ========== CONSTRUCTOR ==========
    
    /**
     * @dev Constructor
     * @param _charityWallet Address to receive charity fees
     * @param _liquidityManager Address of the DOVELiquidityManager contract
     */
    constructor(
        address _charityWallet,
        address _liquidityManager
    ) ERC20("DOVE", "DOVE") Ownable(msg.sender) {
        require(_charityWallet != address(0), "Zero charity wallet");
        require(_liquidityManager != address(0), "Zero liquidity manager");
        
        charityWallet = _charityWallet;
        liquidityManager = DOVELiquidityManager(_liquidityManager);
        
        // Record launch timestamp
        launchTimestamp = block.timestamp;
        
        // Mint total supply to deployer
        _mint(msg.sender, MAX_SUPPLY);
        
        // Set exemptions
        isExemptFromFees[msg.sender] = true;
        isExemptFromFees[address(this)] = true;
        isExemptFromFees[address(0)] = true;
        isExemptFromFees[_charityWallet] = true;
        isExemptFromFees[_liquidityManager] = true;
    }
    
    // ========== MODIFIERS ==========
    
    /**
     * @dev Ensures the passed address is not the zero address
     */
    modifier validAddress(address addr) {
        if (addr == address(0)) revert DOVEErrors.ZeroAddress();
        _;
    }
    
    // ========== VIEW FUNCTIONS ==========
    
    /**
     * @dev Calculate the current sell tax based on time since launch
     * @return Current sell tax in basis points
     */
    function getCurrentSellTax() public view returns (uint256) {
        // If launch time is in the future (should never happen), return initial tax
        if (block.timestamp < launchTimestamp) {
            return INITIAL_SELL_TAX;
        }
        
        // Calculate days since launch
        uint256 daysSinceLaunch = (block.timestamp - launchTimestamp) / 1 days;
        
        // If beyond tax period, tax is zero
        if (daysSinceLaunch >= DAYS_TO_ZERO_TAX) {
            return 0;
        }
        
        // Linear tapering of tax based on days
        // Days 0-2: 3%, Days 2-4: 2%, Days 4-7: 1%
        if (daysSinceLaunch < 2) {
            return INITIAL_SELL_TAX; // 3%
        } else if (daysSinceLaunch < 4) {
            return 200; // 2%
        } else {
            return 100; // 1%
        }
    }
    
    // ========== PUBLIC FUNCTIONS ==========
    
    /**
     * @dev Overridden transfer function that applies fees on sell transfers
     * @param recipient Address receiving the tokens
     * @param amount Amount to transfer
     * @return Whether the transfer was successful
     */
    function transfer(address recipient, uint256 amount) public override(ERC20, IERC20) returns (bool) {
        return _customTransfer(msg.sender, recipient, amount);
    }
    
    /**
     * @dev Overridden transferFrom function that applies fees on sell transfers
     * @param sender Address sending the tokens
     * @param recipient Address receiving the tokens
     * @param amount Amount to transfer
     * @return Whether the transfer was successful
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override(ERC20, IERC20) returns (bool) {
        address spender = msg.sender;
        _spendAllowance(sender, spender, amount);
        return _customTransfer(sender, recipient, amount);
    }
    
    // ========== OWNER FUNCTIONS ==========
    
    /**
     * @dev Set a new charity wallet address
     * @param _charityWallet New charity wallet address
     */
    function setCharityWallet(address _charityWallet) external onlyOwner validAddress(_charityWallet) {
        charityWallet = _charityWallet;
        emit CharityWalletUpdated(_charityWallet);
    }
    
    /**
     * @dev Set a new liquidity manager
     * @param _liquidityManager New liquidity manager address
     */
    function setLiquidityManager(address _liquidityManager) external onlyOwner validAddress(_liquidityManager) {
        liquidityManager = DOVELiquidityManager(_liquidityManager);
        isExemptFromFees[_liquidityManager] = true;
        emit LiquidityManagerUpdated(_liquidityManager);
    }
    
    /**
     * @dev Set fee exemption status for an address
     * @param account Address to set exemption for
     * @param exempt Whether the address should be exempt from fees
     */
    function setFeeExemption(address account, bool exempt) external onlyOwner validAddress(account) {
        isExemptFromFees[account] = exempt;
        emit FeeExemptionUpdated(account, exempt);
    }
    
    /**
     * @dev Pause token transfers
     */
    function pause() external onlyOwner {
        _pause();
        emit TokenPaused(msg.sender);
    }
    
    /**
     * @dev Unpause token transfers
     */
    function unpause() external onlyOwner {
        _unpause();
        emit TokenUnpaused(msg.sender);
    }
    
    /**
     * @dev Recover any tokens accidentally sent to this contract
     * @param token The token to recover
     * @param amount Amount to recover
     * @param to Address to send recovered tokens to
     */
    function recoverToken(address token, uint256 amount, address to) external onlyOwner validAddress(to) {
        // Prevent draining token if recovery is attempted on the DOVE token itself
        if (token == address(this)) revert DOVEErrors.CannotRecoverDOVE();
        
        IERC20(token).safeTransfer(to, amount);
        emit TokenRecovered(token, amount, to);
    }
    
    // ========== INTERNAL FUNCTIONS ==========
    
    /**
     * @dev Internal transfer function that applies fees
     * @param sender Address sending the tokens
     * @param recipient Address receiving the tokens
     * @param amount Amount to transfer
     * @return Whether the transfer was successful
     */
    function _customTransfer(address sender, address recipient, uint256 amount) internal whenNotPaused nonReentrant returns (bool) {
        // Skip fee processing if either address is exempt
        if (isExemptFromFees[sender] || isExemptFromFees[recipient]) {
            _transfer(sender, recipient, amount);
            return true;
        }
        
        // Get current sell tax
        uint256 sellTax = getCurrentSellTax();
        
        // If tax is zero, process normal transfer
        if (sellTax == 0) {
            _transfer(sender, recipient, amount);
            return true;
        }
        
        // Calculate tax amounts
        uint256 totalFeeAmount = (amount * sellTax) / 10000;
        uint256 charityAmount = (amount * CHARITY_FEE) / 10000;
        uint256 liquidityAmount = totalFeeAmount - charityAmount;
        
        // Calculate final amount after fees
        uint256 transferAmount = amount - totalFeeAmount;
        
        // Process transfers
        _transfer(sender, address(this), totalFeeAmount);
        _transfer(sender, recipient, transferAmount);
        
        // Send charity fee
        if (charityAmount > 0) {
            _transfer(address(this), charityWallet, charityAmount);
        }
        
        // Process auto-LP
        if (liquidityAmount > 0) {
            _processAutoLP(liquidityAmount);
        }
        
        emit TransferWithFee(sender, recipient, amount, totalFeeAmount);
        return true;
    }
    
    /**
     * @dev Process auto-LP functionality
     * @param amount Amount of DOVE tokens to use for liquidity
     */
    function _processAutoLP(uint256 amount) internal {
        // Split amount - 50% for liquidity, 50% for burning
        uint256 amountForLP = amount / 2;
        uint256 amountForBurning = amount - amountForLP;
        
        // Approve tokens for liquidity manager
        _approve(address(this), address(liquidityManager), amountForLP);
        
        // Try to add liquidity using current pair
        try liquidityManager.addLiquidityFromToken(amountForLP) {
            // Emit success event
            emit AutoLiquidityAdded(amountForLP);
        } catch {
            // If adding liquidity fails, just burn all tokens
            amountForBurning = amount;
        }
        
        // Burn tokens
        if (amountForBurning > 0) {
            _burn(address(this), amountForBurning);
            emit TokensBurned(amountForBurning);
        }
    }
    
    /**
     * @dev Override ERC20 _update (transfer) to include pausable functionality
     */
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
    }
}
