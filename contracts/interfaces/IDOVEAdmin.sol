// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title IDOVEAdmin
 * @dev Interface for DOVEAdmin contract
 */
interface IDOVEAdmin is IAccessControl {
    // ================ Function Declarations ================
    
    /**
     * @dev Set the DOVE token address
     * @param tokenAddress Address of the DOVE token
     */
    function setTokenAddress(address tokenAddress) external;
    
    /**
     * @dev Launch the DOVE token
     */
    function launch() external;
    
    /**
     * @dev Pause the DOVE token
     */
    function pause() external;
    
    /**
     * @dev Set the charity wallet address
     * @param newCharityWallet Address of the new charity wallet
     */
    function setCharityWallet(address newCharityWallet) external;
    
    /**
     * @dev Exclude an address from fees
     * @param account Address to exclude from fees
     * @param excluded Whether the address is excluded
     */
    function excludeFromFee(address account, bool excluded) external;
    
    /**
     * @dev Set a DEX address status
     * @param dexAddress Address to set status for
     * @param dexStatus Whether the address is a DEX
     */
    function setDexStatus(address dexAddress, bool dexStatus) external;
    
    /**
     * @dev Disable the early sell tax
     */
    function disableEarlySellTax() external;
    
    /**
     * @dev Disable the max transaction limit
     */
    function disableMaxTxLimit() external;
    
    /**
     * @dev Get the DOVE token address
     * @return Address of the DOVE token
     */
    function getTokenAddress() external view returns (address);
    
    // ================ Events ================
    
    /**
     * @dev Emitted when the token address is set
     * @param tokenAddress Address of the token
     */
    event TokenAddressSet(address indexed tokenAddress);
    
    /**
     * @dev Emitted when the charity wallet is changed
     * @param oldWallet Previous charity wallet address
     * @param newWallet New charity wallet address
     */
    event CharityWalletUpdated(address indexed oldWallet, address indexed newWallet);
    
    /**
     * @dev Emitted when an address is excluded from fees
     * @param account Address that was excluded
     * @param isExcluded Whether the address is excluded
     */
    event ExcludedFromFeeUpdated(address indexed account, bool isExcluded);
    
    /**
     * @dev Emitted when a DEX address status is set
     * @param dexAddress Address that was updated
     * @param dexStatus Whether the address is a DEX
     */
    event DexStatusUpdated(address indexed dexAddress, bool dexStatus);
    
    /**
     * @dev Emitted when the early sell tax is disabled
     */
    event EarlySellTaxDisabled();
    
    /**
     * @dev Emitted when the max transaction limit is disabled
     */
    event MaxTxLimitDisabled();
    
    /**
     * @dev Emitted when the token is launched
     * @param timestamp Time of launch
     */
    event Launch(uint256 timestamp);
}
