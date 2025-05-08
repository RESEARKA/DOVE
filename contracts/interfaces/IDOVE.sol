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

    /**
     * @dev Launch the token, enabling transfers (callable by admin).
     */
    function launch() external;

    /**
     * @dev Set an address as exempt or not exempt from fees (alternative to setFeeExemption, potentially for internal use or direct admin control)
     * @param account Address to update
     * @param excluded Whether the address should be excluded from fees
     */
    function setExcludedFromFee(address account, bool excluded) external;

    /**
     * @dev Set DEX status for an address.
     * @param dexAddress Address of the DEX.
     * @param dexStatus True if it's a DEX, false otherwise.
     */
    function setDexStatus(address dexAddress, bool dexStatus) external;

    /**
     * @dev Disable the early sell tax feature (callable by admin).
     */
    function disableEarlySellTax() external;

    /**
     * @dev Disable the maximum transaction limit feature (callable by admin).
     */
    function disableMaxTxLimit() external;

    /**
     * @dev Disable the maximum wallet limit feature (callable by admin).
     */
    function disableMaxWalletLimit() external;

    /**
     * @dev Sets the addresses of secondary helper contracts (events, governance, info).
     * @param eventsContract Address of the DOVEEvents contract.
     * @param governanceContract Address of the IDOVEGovernance contract.
     * @param infoContract Address of the IDOVEInfo contract.
     */
    function setSecondaryContracts(address eventsContract, address governanceContract, address infoContract) external;

    /**
     * @dev Checks if an account is always exempt from fees (e.g., contract address, LP pair).
     * @param account The address to check.
     * @return True if the account is always exempt from fees, false otherwise.
     */
    function isAlwaysFeeExempt(address account) external view returns (bool);

    /**
     * @dev Transfer fee tokens held by the contract to a recipient.
     */
    function transferFeeFromContract(address from, address to, uint256 amount) external returns (bool);

    /**
     * @dev Burn fee tokens held by the contract.
     */
    function burnFeeFromContract(address from, uint256 amount) external returns (bool);

    /**
     * @dev Emit event when charity wallet updated (called by fee manager).
     */
    function emitCharityWalletUpdated(address oldWallet, address newWallet) external;

    /**
     * @dev Emit event when fee exclusion updated.
     */
    function emitExcludedFromFeeUpdated(address account, bool excluded) external;

    /**
     * @dev Emit event when DEX status updated.
     */
    function emitDexStatusUpdated(address dexAddress, bool isDex) external;

    /**
     * @dev Emit event when early sell tax disabled.
     */
    function emitEarlySellTaxDisabled() external;

    /**
     * @dev Emit event when max transaction limit disabled.
     */
    function emitMaxTxLimitDisabled() external;

    /**
     * @dev Emit event when max wallet limit disabled.
     */
    function emitMaxWalletLimitDisabled() external;

    /**
     * @dev Emit event when liquidity manager updated.
     */
    function emitLiquidityManagerUpdated(address newManager) external;

    /**
     * @dev Emit event when tokens recovered.
     */
    function emitTokenRecovered(address token, uint256 amount, address to) external;
}
