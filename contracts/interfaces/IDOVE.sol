// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IDOVE Interface
 * @dev Interface for the DOVEv3 token with action methods
 * Extends standard IERC20 with additional functionality
 */
interface IDOVE is IERC20 {
    /**
     * @dev Pause all token transfers
     */
    function pause() external;
    
    /**
     * @dev Unpause all token transfers
     */
    function unpause() external;
    
    /**
     * @dev Set charity wallet address
     * @param _charityWallet New charity wallet address
     */
    function setCharityWallet(address _charityWallet) external;
    
    /**
     * @dev Set a new liquidity manager address
     * @param _liquidityManager New liquidity manager address
     */
    function setLiquidityManager(address _liquidityManager) external;
    
    /**
     * @dev Set an address as exempt or not exempt from fees
     * @param account Address to update
     * @param exempt Whether the address should be exempt from fees
     */
    function setFeeExemption(address account, bool exempt) external;
    
    /**
     * @dev Recover any tokens accidentally sent to this contract
     * @param token The token to recover
     * @param amount Amount to recover
     * @param to Address to send recovered tokens to
     */
    function recoverToken(address token, uint256 amount, address to) external;
    
    /**
     * @dev Returns true if token transfers are paused
     * @return Whether the token is paused
     */
    function paused() external view returns (bool);
}
