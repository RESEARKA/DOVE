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
}
