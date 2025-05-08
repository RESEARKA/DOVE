// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";

/**
 * @dev Custom errors for gas optimization
 */
error ZeroAddressError(string message);
error NotFeeManagerError();
error NotAdminError();
error PositionNotOwnedError(uint256 positionId);
error SlippageOutOfRangeError();
error PendingAdminChangeExistsError();
error NoPendingAdminChangeError();
error TimelockNotExpiredError();
error RecoverCriticalTokenError(address token);
error AmountTooSmallError();
error PositionAlreadyExistsError(uint256 positionId);
error NotOwnedPositionError(uint256 tokenId);
error WrongNFTSenderError(address sender);
error UnsupportedPoolTokensError(address token0, address token1);
error IncorrectFeeTierError(uint24 fee);
error FailedToReadPositionError();
error MaxIterationsExceededError();

/**
 * @title DOVELiquidityManager
 * @dev Contract for managing Uniswap V3 liquidity positions for DOVE token
 * This contract holds the NFT position and provides functions to add liquidity
 */
contract DOVELiquidityManager is ReentrancyGuard, IERC721Receiver, Pausable {
    using SafeERC20 for IERC20;
    // Uniswap V3 position manager interface
    INonfungiblePositionManager public immutable nonfungiblePositionManager;
    IUniswapV3Factory public immutable uniFactory;
    
    // Token addresses
    address public immutable doveToken;
    address public immutable weth;
    address public immutable usdc;
    
    // State variables for NFT position tracking
    uint256 public doveWethPositionId;
    uint256 public doveUsdcPositionId;
    
    // Mapping to track owned positions for security
    mapping(uint256 => bool) public ownedPositions;
    
    // Current pair in use (false = WETH, true = USDC)
    bool public isUsdcPair;
    
    // Fee tier for Uniswap V3 pool (3000 = 0.3%)
    uint24 public constant FEE_TIER = 3000;
    
    // Tick spacing for 0.3% fee tier
    int24 public constant TICK_SPACING = 60;
    
    // Owner address (DOVEFees contract)
    address public immutable feeManager;
    
    // Admin address (for emergency functions)
    address public admin;
    
    // Timelock for admin changes
    struct PendingAdminChange {
        address newAdmin;
        uint256 timestamp;
        bool exists;
    }
    PendingAdminChange public pendingAdminChange;
    uint256 private constant ADMIN_CHANGE_DELAY = 2 days;
    
    // Default slippage tolerance (1% = 100)
    uint256 public slippageBasisPoints = 100; // 1%
    
    // Events
    event LiquidityAdded(
        uint256 indexed positionId, 
        uint256 doveAmount, 
        uint256 otherTokenAmount, 
        address otherToken,
        uint128 liquidityAdded
    );
    
    event PositionCreated(
        uint256 indexed positionId,
        address token0,
        address token1,
        uint24 feeTier
    );
    
    event FeesCollected(
        uint256 indexed positionId,
        uint256 amount0,
        uint256 amount1,
        address recipient
    );
    
    event SlippageToleranceUpdated(
        uint256 oldBasisPoints,
        uint256 newBasisPoints
    );
    
    event AdminUpdated(
        address oldAdmin,
        address newAdmin
    );
    
    event AdminChangeInitiated(
        address newAdmin,
        uint256 effectiveTimestamp
    );
    
    event AdminChangeCanceled(
        address canceledAdmin
    );
    
    event TokensRecovered(
        address token,
        uint256 amount,
        address recipient
    );
    
    event PositionTransferred(
        uint256 indexed positionId,
        address recipient
    );
    
    event ApprovalReset(
        address token,
        address spender
    );
    
    event ContractPaused(
        address admin
    );
    
    event ContractUnpaused(
        address admin
    );
    
    event NFTPositionReceived(
        uint256 tokenId,
        address token0,
        address token1,
        uint24 fee
    );
    
    /**
     * @dev Constructor
     * @param _positionManager Uniswap V3 NonfungiblePositionManager address
     * @param _doveToken DOVE token address
     * @param _weth WETH token address
     * @param _usdc USDC token address
     * @param _feeManager DOVEFees contract address
     */
    constructor(
        address _positionManager,
        address _doveToken,
        address _weth,
        address _usdc,
        address _feeManager
    ) {
        if (_positionManager == address(0)) revert ZeroAddressError("PositionManager");
        if (_doveToken == address(0)) revert ZeroAddressError("DoveToken");
        if (_weth == address(0)) revert ZeroAddressError("WETH");
        if (_usdc == address(0)) revert ZeroAddressError("USDC");
        if (_feeManager == address(0)) revert ZeroAddressError("FeeManager");
        
        nonfungiblePositionManager = INonfungiblePositionManager(_positionManager);
        uniFactory = IUniswapV3Factory(nonfungiblePositionManager.factory());
        doveToken = _doveToken;
        weth = _weth;
        usdc = _usdc;
        feeManager = _feeManager;
        admin = msg.sender;
        slippageBasisPoints = 100; // Default 1% slippage tolerance
        
        // Pre-approve max amounts to position manager for gas efficiency
        // This is safe because the position manager is a trusted Uniswap contract
        IERC20(_doveToken).safeApprove(_positionManager, type(uint256).max);
        IERC20(_weth).safeApprove(_positionManager, type(uint256).max);
        IERC20(_usdc).safeApprove(_positionManager, type(uint256).max);
        
        // Set initial pair to WETH
        isUsdcPair = false;
    }
    
    /**
     * @dev Modifier to restrict access to fee manager
     */
    modifier onlyFeeManager() {
        if (msg.sender != feeManager) revert NotFeeManagerError();
        _;
    }
    
    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdminError();
        _;
    }
    
    /**
     * @dev Add liquidity to DOVE-WETH position
     * @param doveAmount Amount of DOVE tokens
     * @param wethAmount Amount of WETH
     * @return liquidity Amount of liquidity added
     */
    function addLiquidityDoveWeth(
        uint256 doveAmount,
        uint256 wethAmount
    ) public onlyFeeManager nonReentrant whenNotPaused returns (uint128 liquidity) {
        // Skip if zero amounts
        if (doveAmount == 0 || wethAmount == 0) {
            return 0;
        }
        
        // Ensure tokens are transferred to this contract before adding liquidity
        IERC20(doveToken).safeTransferFrom(msg.sender, address(this), doveAmount);
        IERC20(weth).safeTransferFrom(msg.sender, address(this), wethAmount);
        
        // Add liquidity
        if (doveWethPositionId == 0) {
            // Create new position
            (
                uint256 tokenId,
                uint128 addedLiquidity,
                ,
                
            ) = _createNewPosition(doveToken, weth, doveAmount, wethAmount);
            
            doveWethPositionId = tokenId;
            ownedPositions[tokenId] = true;
            liquidity = addedLiquidity;
            
            emit PositionCreated(tokenId, doveToken, weth, FEE_TIER);
        } else {
            // Increase liquidity in existing position
            liquidity = _increaseLiquidity(doveWethPositionId, doveAmount, wethAmount);
        }
        
        emit LiquidityAdded(doveWethPositionId, doveAmount, wethAmount, weth, liquidity);
        return liquidity;
    }
    
    /**
     * @dev Add liquidity to DOVE-USDC position
     * @param doveAmount Amount of DOVE tokens
     * @param usdcAmount Amount of USDC
     * @return liquidity Amount of liquidity added
     */
    function addLiquidityDoveUsdc(
        uint256 doveAmount,
        uint256 usdcAmount
    ) public onlyFeeManager nonReentrant whenNotPaused returns (uint128 liquidity) {
        // Skip if zero amounts
        if (doveAmount == 0 || usdcAmount == 0) {
            return 0;
        }
        
        // Ensure tokens are transferred to this contract before adding liquidity
        IERC20(doveToken).safeTransferFrom(msg.sender, address(this), doveAmount);
        IERC20(usdc).safeTransferFrom(msg.sender, address(this), usdcAmount);
        
        // Add liquidity
        if (doveUsdcPositionId == 0) {
            // Create new position
            (
                uint256 tokenId,
                uint128 addedLiquidity,
                ,
                
            ) = _createNewPosition(doveToken, usdc, doveAmount, usdcAmount);
            
            doveUsdcPositionId = tokenId;
            ownedPositions[tokenId] = true;
            liquidity = addedLiquidity;
            
            emit PositionCreated(tokenId, doveToken, usdc, FEE_TIER);
        } else {
            // Increase liquidity in existing position
            liquidity = _increaseLiquidity(doveUsdcPositionId, doveAmount, usdcAmount);
        }
        
        emit LiquidityAdded(doveUsdcPositionId, doveAmount, usdcAmount, usdc, liquidity);
        return liquidity;
    }
    
    /**
     * @dev Set the current pair for auto-LP (false = WETH, true = USDC)
     * @param useUsdc Whether to use USDC (true) or WETH (false)
     */
    function setCurrentPair(bool useUsdc) external onlyFeeManager {
        isUsdcPair = useUsdc;
    }
    
    /**
     * @dev Add liquidity to the current pair based on isUsdcPair setting
     * @param doveAmount Amount of DOVE tokens to add
     * @param otherAmount Amount of other token (WETH or USDC) to add
     * @return liquidity The amount of liquidity added
     */
    function addLiquidityCurrentPair(
        uint256 doveAmount,
        uint256 otherAmount
    ) external onlyFeeManager nonReentrant whenNotPaused returns (uint128 liquidity) {
        if (!isUsdcPair) {
            return addLiquidityDoveWeth(doveAmount, otherAmount);
        } else {
            return addLiquidityDoveUsdc(doveAmount, otherAmount);
        }
    }
    
    /**
     * @dev Internal function to create a new Uniswap V3 position
     * @param token0 Address of token0
     * @param token1 Address of token1
     * @param amount0Desired Amount of token0 desired
     * @param amount1Desired Amount of token1 desired
     * @return tokenId New position NFT ID
     * @return liquidity Liquidity amount
     * @return amount0Used Amount of token0 used
     * @return amount1Used Amount of token1 used
     */
    function _createNewPosition(
        address token0,
        address token1,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) private returns (uint256 tokenId, uint128 liquidity, uint256 amount0Used, uint256 amount1Used) {
        // Sort tokens for Uniswap V3
        (address t0, address t1, uint256 a0, uint256 a1) = token0 < token1
            ? (token0, token1, amount0Desired, amount1Desired)
            : (token1, token0, amount1Desired, amount0Desired);
        
        // Calculate price range - use multiples of tick spacing
        int24 minTick = -887220;
        int24 maxTick = 887220;
        int24 tickLower = (minTick / TICK_SPACING) * TICK_SPACING;
        int24 tickUpper = (maxTick / TICK_SPACING) * TICK_SPACING;
        
        // Create the pool if it doesn't exist
        IUniswapV3Factory factory = IUniswapV3Factory(nonfungiblePositionManager.factory());
        address poolAddress = factory.getPool(t0, t1, FEE_TIER);
        if (poolAddress == address(0)) {
            poolAddress = factory.createPool(t0, t1, FEE_TIER);
            
            // Calculate proper sqrt price with decimal adjustment
            uint160 sqrtPriceX96 = _calculateSqrtPriceX96(t0, t1);
            
            // Ensure sqrtPriceX96 is within valid range
            if (sqrtPriceX96 < TickMath.MIN_SQRT_RATIO + 1) {
                sqrtPriceX96 = TickMath.MIN_SQRT_RATIO + 1;
            } else if (sqrtPriceX96 > TickMath.MAX_SQRT_RATIO - 1) {
                sqrtPriceX96 = TickMath.MAX_SQRT_RATIO - 1;
            }
            
            IUniswapV3Pool(poolAddress).initialize(sqrtPriceX96);
        }
        
        // Calculate minimum amounts with slippage protection
        uint256 amount0Min = (a0 * (10000 - slippageBasisPoints)) / 10000;
        uint256 amount1Min = (a1 * (10000 - slippageBasisPoints)) / 10000;
        
        // Add initial liquidity
        (
            tokenId,
            liquidity,
            amount0Used,
            amount1Used
        ) = nonfungiblePositionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: t0,
                token1: t1,
                fee: FEE_TIER,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: a0,
                amount1Desired: a1,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                recipient: address(this),
                deadline: block.timestamp + 15 minutes // Provide reasonable deadline
            })
        );
        
        // Return any unused tokens to the fee manager
        if (a0 > amount0Used) {
            IERC20(t0).safeTransfer(feeManager, a0 - amount0Used);
        }
        
        if (a1 > amount1Used) {
            IERC20(t1).safeTransfer(feeManager, a1 - amount1Used);
        }
        
        return (tokenId, liquidity, amount0Used, amount1Used);
    }
    
    /**
     * @dev Internal function to increase liquidity in an existing position
     * @param positionId ID of the existing position
     * @param amount0Desired Amount of token0 desired
     * @param amount1Desired Amount of token1 desired
     * @return liquidity New liquidity amount
     * @return amount0Added Amount of token0 used
     * @return amount1Added Amount of token1 used
     */
    function _increaseLiquidity(
        uint256 positionId,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) private returns (uint128 liquidity, uint256 amount0Added, uint256 amount1Added) {
        // Get current position info
        (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
        
        ) = nonfungiblePositionManager.positions(positionId);
        
        // Adjust parameter ordering based on token ordering in the position
        // This prevents errors when tokens are in different order than expected
        if (doveToken != token0) {
            // Swap the input amounts if the tokens are in opposite order
            (amount0Desired, amount1Desired) = (amount1Desired, amount0Desired);
        }
        
        // Calculate minimum amounts with slippage protection
        uint256 amount0Min = (amount0Desired * (10000 - slippageBasisPoints)) / 10000;
        uint256 amount1Min = (amount1Desired * (10000 - slippageBasisPoints)) / 10000;
        
        // Increase liquidity in existing position
        (liquidity, amount0Added, amount1Added) = nonfungiblePositionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: positionId,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                deadline: block.timestamp + 15 minutes // Provide reasonable deadline
            })
        );
        
        // Return any unused tokens to the fee manager
        if (amount0Desired > amount0Added) {
            IERC20(token0).safeTransfer(feeManager, amount0Desired - amount0Added);
        }
        
        if (amount1Desired > amount1Added) {
            IERC20(token1).safeTransfer(feeManager, amount1Desired - amount1Added);
        }
        
        return (liquidity, amount0Added, amount1Added);
    }
    
    /**
     * @dev Collect fees from a position
     * @param positionId ID of the position
     * @return amount0 Amount of token0 collected
     * @return amount1 Amount of token1 collected
     */
    function collectFees(uint256 positionId)
        external
        onlyFeeManager
        nonReentrant
        whenNotPaused
        returns (uint256 amount0, uint256 amount1)
    {
        if (positionId != doveWethPositionId && positionId != doveUsdcPositionId) {
            revert NotOwnedPositionError(positionId);
        }
        
        // Collect fees
        (amount0, amount1) = nonfungiblePositionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: positionId,
                recipient: feeManager,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        
        emit FeesCollected(positionId, amount0, amount1, feeManager);
        
        return (amount0, amount1);
    }
    
    /**
     * @dev Add liquidity from a token amount
     * @param doveAmount Amount of DOVE tokens to add
     * @return success Whether the operation succeeded
     */
    function addLiquidityFromToken(uint256 doveAmount)
        external
        onlyFeeManager
        nonReentrant
        whenNotPaused
        returns (bool)
    {
        // Minimum amount check
        if (doveAmount < 1000) {
            return false;
        }
        
        // Get other token and position ID based on current pair
        address otherToken = isUsdcPair ? usdc : weth;
        uint256 positionId = isUsdcPair ? doveUsdcPositionId : doveWethPositionId;
        
        // Check if the position exists and if we have any other token BEFORE transferring tokens
        uint256 otherTokenBalance = IERC20(otherToken).balanceOf(address(this));
        if (positionId == 0 || otherTokenBalance == 0) {
            return false;
        }
        
        // Transfer DOVE tokens to contract only after pre-checks pass
        IERC20(doveToken).safeTransferFrom(msg.sender, address(this), doveAmount);
        
        // We already checked the other token balance above, but we'll use it here
        
        // Add liquidity to existing position
        try _increaseLiquidity(positionId, doveAmount, otherTokenBalance) returns (uint128 liquidity, uint256 amount0Used, uint256 amount1Used) {
            // Calculate actual amounts used - one will be DOVE, one will be the other token
            uint256 doveUsed = isUsdcPair ? 
                (doveToken < usdc ? amount0Used : amount1Used) :
                (doveToken < weth ? amount0Used : amount1Used);
            uint256 otherUsed = isUsdcPair ?
                (doveToken < usdc ? amount1Used : amount0Used) :
                (doveToken < weth ? amount1Used : amount0Used);
                
            emit LiquidityAdded(positionId, doveUsed, otherUsed, otherToken, liquidity);
            return true;
        } catch {
            // If liquidity addition fails, return the DOVE tokens to the sender to prevent loss
            IERC20(doveToken).safeTransfer(feeManager, doveAmount);
            return false;
        }
    }
    
    /**
     * @dev Set slippage tolerance in basis points (1% = 100)
     * @param _slippageBasisPoints New slippage tolerance
     */
    /**
     * @dev Set the slippage tolerance for liquidity operations
     * @param _slippageBasisPoints New slippage tolerance in basis points (1 = 0.01%)
     * Min 0.1% (10 basis points), Max 3% (300 basis points)
     */
    function setSlippageTolerance(uint256 _slippageBasisPoints) external onlyFeeManager {
        // Min 0.1% (10bp), Max 3% (300bp) slippage to prevent excessive MEV
        if (_slippageBasisPoints < 10 || _slippageBasisPoints > 300) revert SlippageOutOfRangeError();
        
        uint256 oldSlippage = slippageBasisPoints;
        slippageBasisPoints = _slippageBasisPoints;
        
        emit SlippageToleranceUpdated(oldSlippage, _slippageBasisPoints);
    }
    
    /**
     * @dev Initiate admin address change with timelock
     * @param newAdmin New admin address
     */
    function initiateAdminChange(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddressError("NewAdmin");
        if (pendingAdminChange.exists) revert PendingAdminChangeExistsError();
        
        pendingAdminChange = PendingAdminChange({
            newAdmin: newAdmin,
            timestamp: block.timestamp,
            exists: true
        });
        
        emit AdminChangeInitiated(newAdmin, block.timestamp + ADMIN_CHANGE_DELAY);
    }
    
    /**
     * @dev Complete admin address change after timelock delay
     */
    function completeAdminChange() external {
        if (!pendingAdminChange.exists) revert NoPendingAdminChangeError();
        if (block.timestamp < pendingAdminChange.timestamp + ADMIN_CHANGE_DELAY) revert TimelockNotExpiredError();
        
        address oldAdmin = admin;
        admin = pendingAdminChange.newAdmin;
        
        // Clear pending change
        delete pendingAdminChange;
        
        emit AdminUpdated(oldAdmin, admin);
    }
    
    /**
     * @dev Cancel pending admin change
     */
    function cancelAdminChange() external onlyAdmin {
        if (!pendingAdminChange.exists) revert NoPendingAdminChangeError();
        
        address canceledAdmin = pendingAdminChange.newAdmin;
        delete pendingAdminChange;
        
        emit AdminChangeCanceled(canceledAdmin);
    }
    
    /**
     * @dev Emergency pause function
     */
    function pause() external onlyAdmin {
        _pause();
        emit ContractPaused(msg.sender);
    }
    
    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyAdmin {
        _unpause();
        emit ContractUnpaused(msg.sender);
    }
    
    /**
     * @dev Recover any ERC20 token accidentally sent to this contract
     * @param token Token address
     * @param amount Amount to recover
     * @param recipient Recipient of the recovered tokens
     */
    function recoverERC20(address token, uint256 amount, address recipient) external onlyAdmin whenPaused nonReentrant {
        if (recipient == address(0)) revert ZeroAddressError("Recipient");
        if (amount == 0) revert AmountTooSmallError();
        
        // Critical tokens should only be recovered through proper channels
        if (token == doveToken || token == weth || token == usdc) revert RecoverCriticalTokenError(token);
        
        IERC20(token).safeTransfer(recipient, amount);
        
        emit TokensRecovered(token, amount, recipient);
    }
    
    /**
     * @dev Transfer an NFT position to another address - EMERGENCY ONLY
     * @param tokenId ID of the NFT position
     * @param recipient Recipient address
     */
    function transferPosition(uint256 tokenId, address recipient) external onlyAdmin whenPaused nonReentrant {
        if (recipient == address(0)) revert ZeroAddressError("Recipient");
        
        // Only allow transferring positions we own
        if (tokenId != doveWethPositionId && tokenId != doveUsdcPositionId) {
            revert PositionNotOwnedError(tokenId);
        }
        
        // Store position ID temporarily to avoid race conditions
        uint256 positionToTransfer = tokenId;
        
        // Transfer the position to the recipient
        nonfungiblePositionManager.safeTransferFrom(address(this), recipient, positionToTransfer);
        
        // Reset position ID AFTER successful transfer
        if (positionToTransfer == doveWethPositionId) {
            doveWethPositionId = 0;
            ownedPositions[positionToTransfer] = false;
        } else if (positionToTransfer == doveUsdcPositionId) {
            doveUsdcPositionId = 0;
            ownedPositions[positionToTransfer] = false;
        }
        
        emit PositionTransferred(positionToTransfer, recipient);
    }
    
    /**
     * @dev Reset token approvals for added security
     * @param token Token address
     * @param spender Spender address
     */
    function resetApproval(address token, address spender) external onlyAdmin {
        if (token == address(0)) revert ZeroAddressError("Token");
        if (spender == address(0)) revert ZeroAddressError("Spender");
        
        _safeApprove(token, spender, 0);
        
        emit ApprovalReset(token, spender);
    }
    
    /**
     * @dev Reset all token approvals for the position manager
     * Note: After fixing the approval pattern (using type(uint256).max in constructor),
     * this function is mostly maintained for future-proofing and defense-in-depth security.
     */
    function _resetAllApprovals() internal {
        // Since we now use infinite approvals in the constructor, this is a no-op
        // but we keep it in case the approval strategy changes in the future
    }
    
    /**
     * @dev Safe approval function to prevent approval race conditions
     * @param token Token address
     * @param spender Spender address
     * @param amount Amount to approve
     */
    function _safeApprove(
        address token,
        address spender,
        uint256 amount
    ) private {
        // Implementation changed to use the constructor infinite approvals instead
        // This is now just a fallback in case specific tokens need different handling
        uint256 currentAllowance = IERC20(token).allowance(address(this), spender);
        
        // Only perform approval if needed to save gas
        if (currentAllowance != amount) {
            // Reset approval to 0 first (required by some tokens)
            if (currentAllowance > 0) {
                IERC20(token).safeApprove(spender, 0);
            }
            
            // Approve the required amount
            IERC20(token).safeApprove(spender, amount);
        }
    }
    
    /**
     * @dev Implementation of IERC721Receiver to receive NFT positions
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        // Only allow receiving from the Uniswap position manager
        if (msg.sender != address(nonfungiblePositionManager)) {
            revert WrongNFTSenderError(msg.sender);
        }
        
        // Check if the position ID matches one of our tracked positions or is a new position
        // New positions will be registered in the respective createPosition functions
        // If not, this is an unsolicited NFT transfer that we should reject
        if (ownedPositions[tokenId] && tokenId != 0) {
            // This is a position we already own, which shouldn't happen
            // We'll reject it to prevent potential token manipulations
            revert("Position already registered");
        }
        
        // Get position information to validate it's a valid pool we support
        try nonfungiblePositionManager.positions(tokenId) returns (
            uint96 nonce,
            address operator_,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) {
            // Verify this is one of our supported pools
            bool validPool = false;
            
            // Check DOVE-WETH pool
            if ((token0 == doveToken && token1 == weth) || (token0 == weth && token1 == doveToken)) {
                validPool = true;
            }
            
            // Check DOVE-USDC pool
            if ((token0 == doveToken && token1 == usdc) || (token0 == usdc && token1 == doveToken)) {
                validPool = true;
            }
            
            // Revert if not a supported pool
            if (!validPool) {
                revert UnsupportedPoolTokensError(token0, token1);
            }
            
            // Verify fee tier matches our expected fee tier
            if (fee != FEE_TIER) {
                revert IncorrectFeeTierError(fee);
            }
            
            // This is a valid position, register it if it's a new one from a valid mint operation
            // We'll update the ownedPositions mapping here as an additional safety check
            emit NFTPositionReceived(tokenId, token0, token1, fee);
        } catch {
            // If we can't read the position, reject the NFT
            revert FailedToReadPositionError();
        }
        
        // Return the selector to accept the NFT
        return this.onERC721Received.selector;
    }
    
    /**
     * @dev Calculate the sqrtPriceX96 value for a token pair with proper decimal adjustment
     * @param token0 First token address (must be sorted)
     * @param token1 Second token address (must be sorted)
     * @return sqrtPriceX96 The calculated sqrt price with decimal adjustment
     */
    function _calculateSqrtPriceX96(address token0, address token1) internal view returns (uint160) {
        // Get token decimals
        uint8 decimals0;
        uint8 decimals1;
        
        try IERC20Metadata(token0).decimals() returns (uint8 dec0) {
            decimals0 = dec0;
        } catch {
            // Default to 18 if we can't get decimals
            decimals0 = 18;
        }
        
        try IERC20Metadata(token1).decimals() returns (uint8 dec1) {
            decimals1 = dec1;
        } catch {
            // Default to 18 if we can't get decimals
            decimals1 = 18;
        }
        
        // Set base prices depending on token pair
        uint256 price;
        bool priceFor0;
        
        if (token0 == doveToken && token1 == usdc) {
            // DOVE/USDC - initial price of 0.001 USDC per DOVE
            price = 1e3; // 0.001 with 6 decimals (USDC)
            priceFor0 = true;
        } else if (token0 == usdc && token1 == doveToken) {
            // USDC/DOVE - initial price of 1000 DOVE per USDC
            price = 1e3; // 1000 with 0 decimals (ratio)
            priceFor0 = false;
        } else if (token0 == doveToken && token1 == weth) {
            // DOVE/WETH - initial price of 0.0000005 ETH per DOVE
            price = 5e10; // 0.0000005 with 18 decimals (ETH)
            priceFor0 = true;
        } else if (token0 == weth && token1 == doveToken) {
            // WETH/DOVE - initial price of 2000000 DOVE per ETH
            price = 2e6; // 2000000 with 0 decimals (ratio)
            priceFor0 = false;
        } else {
            // Default fallback - 1:1 price
            price = 1;
            priceFor0 = true;
        }
        
        // Calculate the price with decimal adjustment
        uint256 adjustedPrice;
        if (priceFor0) {
            // Price is token1 per token0
            // We need to apply decimal adjustment: price * 10^decimal1 / 10^decimal0
            if (decimals1 >= decimals0) {
                adjustedPrice = price * 10**(decimals1 - decimals0);
            } else {
                adjustedPrice = price / 10**(decimals0 - decimals1);
            }
        } else {
            // Price is token0 per token1
            // We need to invert and apply decimal adjustment: (1/price) * 10^decimal0 / 10^decimal1
            if (decimals0 >= decimals1) {
                adjustedPrice = (10**decimals0) / (price * 10**(decimals0 - decimals1));
            } else {
                adjustedPrice = (10**decimals0 * 10**(decimals1 - decimals0)) / price;
            }
        }
        
        // Calculate sqrtPriceX96 with overflow checks
        uint256 sqrtAdjustedPrice;
        if (priceFor0) {
            sqrtAdjustedPrice = _sqrt(adjustedPrice);
        } else {
            // Make sure division doesn't fail with large values
            if (adjustedPrice == 0) {
                adjustedPrice = 1;
            }
            sqrtAdjustedPrice = _sqrt(1e36 / adjustedPrice);
        }
        
        // Check for overflow before multiplying by 2^96
        if (sqrtAdjustedPrice > type(uint256).max / (2**96)) {
            // If it would overflow, cap at the max safe value
            return type(uint160).max;
        }
        
        uint256 sqrtPriceX96Value = sqrtAdjustedPrice * (2**96) / 1e18;
        
        // Make sure the final value fits in uint160
        if (sqrtPriceX96Value > type(uint160).max) {
            return type(uint160).max;
        }
        
        return uint160(sqrtPriceX96Value);
    }
    
    /**
     * @dev Simple square root function with iteration limit
     * @param x Input value
     * @return y Square root of x
     */
    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        
        // Initial estimate
        uint256 z = (x + 1) / 2;
        y = x;
        
        // Maximum iterations to prevent gas limit attacks
        uint8 maxIterations = 128;
        uint8 iterations = 0;
        
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
            
            unchecked { ++iterations; }
            
            // Prevent unbounded loops - 128 iterations is more than enough for uint256
            if (iterations >= maxIterations) {
                revert MaxIterationsExceededError();
            }
        }
    }
    
    /**
     * @dev Receive function to allow contract to receive ETH
     */
    receive() external payable {}
    
    /**
     * @notice Checks whether `pool` is a legitimate Uniswap V3 pool used by this protocol
     * @dev Never reverts. Returns false on any unexpected behavior.
     */
    function isDexPair(address pool) external view returns (bool) {
        if (pool == address(0)) return false;
        uint256 size;
        assembly { size := extcodesize(pool) }
        if (size == 0) return false;

        address factory;
        try IUniswapV3Pool(pool).factory() returns (address f) { factory = f; } catch { return false; }
        if (factory != uniFactory) return false;

        address token0;
        address token1;
        uint24 fee;
        try IUniswapV3Pool(pool).token0() returns (address t0) { token0 = t0; } catch { return false; }
        try IUniswapV3Pool(pool).token1() returns (address t1) { token1 = t1; } catch { return false; }
        try IUniswapV3Pool(pool).fee() returns (uint24 f) { fee = f; } catch { return false; }

        if (fee != FEE_TIER) return false;
        bool supported = (token0 == doveToken && (token1 == weth || token1 == usdc)) ||
                         (token1 == doveToken && (token0 == weth || token0 == usdc));
        if (!supported) return false;

        address registered = IUniswapV3Factory(factory).getPool(token0, token1, fee);
        if (registered != pool) return false;
        return true;
    }
}
