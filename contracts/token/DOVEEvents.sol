// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title DOVEEvents
 * @dev Event declarations for DOVE token ecosystem
 * This interface centralizes all event declarations for the DOVE token
 */
interface DOVEEvents {
    /**
     * @dev Emitted when tokens are transferred with fee applied
     * @param sender Address sending the tokens
     * @param recipient Address receiving the tokens
     * @param amount Total amount of tokens sent
     * @param feeAmount Amount deducted as fee
     */
    event TransferWithFee(address indexed sender, address indexed recipient, uint256 amount, uint256 feeAmount);
    
    /**
     * @dev Emitted when the charity wallet is updated
     * @param newWallet New charity wallet address
     */
    event CharityWalletUpdated(address indexed newWallet);
    
    /**
     * @dev Emitted when liquidity manager is updated
     * @param newManager New liquidity manager address
     */
    event LiquidityManagerUpdated(address indexed newManager);
    
    /**
     * @dev Emitted when an address's fee exemption status is updated
     * @param account Address that was updated
     * @param exempt Whether the address is exempt from fees
     */
    event FeeExemptionUpdated(address indexed account, bool exempt);
    
    /**
     * @dev Emitted when auto-liquidity is added
     * @param amount Amount of DOVE tokens added to liquidity
     */
    event AutoLiquidityAdded(uint256 amount);
    
    /**
     * @dev Emitted when tokens are burned
     * @param amount Amount of tokens burned
     */
    event TokensBurned(uint256 amount);
    
    /**
     * @dev Emitted when the token is paused
     * @param pauser Address that paused the token
     */
    event TokenPaused(address indexed pauser);
    
    /**
     * @dev Emitted when the token is unpaused
     * @param unpauser Address that unpaused the token
     */
    event TokenUnpaused(address indexed unpauser);
    
    /**
     * @dev Emitted when tokens are recovered from the contract
     * @param token Token address that was recovered
     * @param amount Amount of tokens recovered
     * @param to Address receiving the recovered tokens
     */
    event TokenRecovered(address indexed token, uint256 amount, address indexed to);
    
    /**
     * @dev Emitted when auto-liquidity process fails
     * @param amount Amount that was intended for liquidity
     * @param hasErrorData Whether error data was captured
     */
    event AutoLiquidityFailed(uint256 amount, bool hasErrorData);
    
    /**
     * @dev Emitted when the max wallet limit is disabled
     */
    event MaxWalletLimitDisabled();
    
    /**
     * @dev Emitted when the max transaction limit is disabled
     */
    event MaxTxLimitDisabled();
    
    /**
     * @dev Emitted when token officially launches
     */
    event Launch(uint256 timestamp);
    
    /**
     * @dev Emitted when DEX status updated
     */
    event DexStatusUpdated(address indexed dexAddress, bool isDex);

    // helper functions to emit events from other contracts
    /// @notice Emits the {Launch} event.
    /// @param timestamp Block timestamp of launch.
    function emitLaunch(uint256 timestamp) external;
    
    /// @notice Emits the {MaxWalletLimitDisabled} event.
    function emitMaxWalletLimitDisabled() external;
    
    /// @notice Emits the {MaxTxLimitDisabled} event.
    function emitMaxTxLimitDisabled() external;
    
    /// @notice Emits the {DexStatusUpdated} event.
    /// @param dexAddress Address flagged/unflagged as dex.
    /// @param isDex True if flagged as DEX
    function emitDexStatusUpdated(address dexAddress, bool isDex) external;
    
    /// @notice Emits the {LiquidityManagerUpdated} event.
    /// @param newManager New liquidity manager address.
    function emitLiquidityManagerUpdated(address newManager) external;
    
    /// @notice Emits the {TokenRecovered} event.
    /// @param token Token address.
    /// @param amount Amount recovered.
    /// @param to Receiver address.
    function emitTokenRecovered(address token, uint256 amount, address to) external;
    
    /// @notice Emits the {CharityWalletUpdated} event.
    /// @param newWallet New charity wallet.
    function emitCharityWalletUpdated(address newWallet) external;
    
    /// @notice Emits the {FeeExemptionUpdated} event.
    /// @param account Address updated.
    /// @param exempt True if now exempt.
    function emitFeeExemptionUpdated(address account, bool exempt) external;
    
    /// @notice Emits the {AutoLiquidityAdded} event.
    /// @param amount Amount of tokens.
    function emitAutoLiquidityAdded(uint256 amount) external;
    
    /// @notice Emits the {TokensBurned} event.
    /// @param amount Amount burned.
    function emitTokensBurned(uint256 amount) external;
    
    /// @notice Emits the {TokenPaused} event.
    /// @param pauser Address that paused.
    function emitTokenPaused(address pauser) external;
    
    /// @notice Emits the {TokenUnpaused} event.
    /// @param unpauser Address that unpaused.
    function emitTokenUnpaused(address unpauser) external;
    
    /// @notice Emits the {AutoLiquidityFailed} event.
    /// @param amount Intended liquidity amount.
    /// @param hasErrorData True if error data was returned.
    function emitAutoLiquidityFailed(uint256 amount, bool hasErrorData) external;
}
