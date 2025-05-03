// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title DOVE Admin Interface
 * @dev Interface for DOVE token administration functionality
 * This interface centralizes all admin and configuration operations
 */
interface IDOVEAdmin {
    /**
     * @dev Role constants
     * These roles control access to administrative functions
     */
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function FEE_MANAGER_ROLE() external view returns (bytes32);
    function EMERGENCY_ADMIN_ROLE() external view returns (bytes32);
    function PAUSER_ROLE() external view returns (bytes32);
    
    /**
     * @dev Launch the token, enabling transfers
     * @notice Requires DEFAULT_ADMIN_ROLE
     * Can only be called once by admin
     */
    function launch() external;
    
    /**
     * @dev Set charity wallet address
     * @param newCharityWallet New charity wallet address
     * @notice Requires FEE_MANAGER_ROLE
     */
    function setCharityWallet(address newCharityWallet) external;
    
    /**
     * @dev Exclude or include an address from fees
     * @param account Address to update
     * @param excluded Whether to exclude from fees
     * @notice Requires DEFAULT_ADMIN_ROLE or FEE_MANAGER_ROLE
     */
    function excludeFromFee(address account, bool excluded) external;
    
    /**
     * @dev Set a DEX address status
     * @param dexAddress Address to set status for
     * @param isDex Whether the address is a DEX
     * @notice Requires DEFAULT_ADMIN_ROLE
     */
    function setDexStatus(address dexAddress, bool isDex) external;
    
    /**
     * @dev Disable early sell tax permanently (emergency function)
     * @notice Requires EMERGENCY_ADMIN_ROLE
     * Can only be called by emergency admin
     */
    function disableEarlySellTax() external;
    
    /**
     * @dev Disable max transaction limit permanently
     * @notice Requires DEFAULT_ADMIN_ROLE
     * Can only be called by admin
     */
    function disableMaxTxLimit() external;
    
    /**
     * @dev Set token address
     * @param tokenAddress Address of the DOVE token
     * @notice Requires DEFAULT_ADMIN_ROLE
     */
    function setTokenAddress(address tokenAddress) external;
    
    /**
     * @dev Pause all token transfers
     * @notice Requires PAUSER_ROLE
     * Can only be called by pauser role
     */
    function pause() external;
    
    /**
     * @dev Unpause all token transfers
     * @notice Requires PAUSER_ROLE
     * Can only be called by pauser role
     */
    function unpause() external;
    
    /**
     * @dev Grant a role to an account
     * @param role Role to grant
     * @param account Account to grant role to
     * @notice Requires admin of the role (typically DEFAULT_ADMIN_ROLE)
     */
    function grantRole(bytes32 role, address account) external;
    
    /**
     * @dev Revoke a role from an account
     * @param role Role to revoke
     * @param account Account to revoke role from
     * @notice Requires admin of the role (typically DEFAULT_ADMIN_ROLE)
     */
    function revokeRole(bytes32 role, address account) external;
    
    /**
     * @dev Renounce a role from caller
     * @param role Role to renounce
     * @param account Account renouncing role (must be caller)
     * @notice Can only be called by the account itself to renounce a role
     */
    function renounceRole(bytes32 role, address account) external;
    
    /**
     * @dev Check if an account has a role
     * @param role Role to check
     * @param account Account to check
     * @return True if account has role
     */
    function hasRole(bytes32 role, address account) external view returns (bool);
    
    /**
     * @dev Events emitted by the DOVE Admin
     */
    event CharityWalletUpdated(address oldWallet, address newWallet);
    event FeeExclusionUpdated(address indexed account, bool excluded);
    event DexStatusUpdated(address indexed dexAddress, bool isDex);
    event EarlySellTaxDisabled();
    event MaxTxLimitDisabled();
    event TokenAddressSet(address tokenAddress);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRenounced(bytes32 indexed role, address indexed account);
}
