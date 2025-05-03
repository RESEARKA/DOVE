// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IDOVE.sol";
import "../interfaces/IDOVEAdmin.sol";

/**
 * @title DOVE Admin Contract
 * @dev Manages administrative functions for the DOVE token
 * Centralizes role management and provides controlled access to token features
 */
contract DOVEAdmin is AccessControl, ReentrancyGuard, IDOVEAdmin {
    // ================ Role Constants ================
    
    // Role definitions
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ADMIN_ROLE = keccak256("EMERGENCY_ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    // ================ State Variables ================
    
    // DOVE token contract
    IDOVE private _doveToken;
    
    // Security flags
    bool private _securityLockdown;
    
    // Reentrancy protection for critical operations
    mapping(bytes32 => uint256) private _operationNonces;
    uint256 private _globalNonce;
    
    // Time delay for critical operations (24 hours)
    uint256 private constant TIMELOCK_DELAY = 24 hours;
    mapping(bytes32 => uint256) private _operationTimelocks;
    
    // ================ Events ================
    
    // Events inherited from IDOVEAdmin interface
    
    // Additional security events
    event SecurityLockdown(bool enabled);
    event OperationScheduled(bytes32 indexed operationId, uint256 executionTime);
    event OperationCancelled(bytes32 indexed operationId);
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor initializes the DOVE Admin contract
     * @param initialAdmin Address of the initial admin
     */
    constructor(address initialAdmin) {
        require(initialAdmin != address(0), "Initial admin cannot be zero address");
        
        // Set up roles
        _setupRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _setupRole(FEE_MANAGER_ROLE, initialAdmin);
        _setupRole(EMERGENCY_ADMIN_ROLE, initialAdmin);
        _setupRole(PAUSER_ROLE, initialAdmin);
    }
    
    // ================ Modifiers ================
    
    /**
     * @dev Enforces timelock for critical operations
     * @param operationId Unique operation identifier
     */
    modifier timelockRequired(bytes32 operationId) {
        // Check if operation is already scheduled
        if (_operationTimelocks[operationId] == 0) {
            // Schedule new operation with timelock
            _operationTimelocks[operationId] = block.timestamp + TIMELOCK_DELAY;
            emit OperationScheduled(operationId, _operationTimelocks[operationId]);
            return; // Exit without executing the operation now
        }
        
        // Check if timelock period has passed
        require(block.timestamp >= _operationTimelocks[operationId], "Timelock period not elapsed");
        
        // Clear timelock to prevent replay
        delete _operationTimelocks[operationId];
        
        // Execute the operation
        _;
    }
    
    /**
     * @dev Prevents operations during security lockdown
     */
    modifier notLocked() {
        require(!_securityLockdown, "Contract is in security lockdown");
        _;
    }
    
    // ================ External Functions ================
    
    /**
     * @dev Launch the token, enabling transfers
     * @notice Requires DEFAULT_ADMIN_ROLE
     */
    function launch() external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) notLocked {
        // Create operation ID using nonce for uniqueness
        bytes32 operationId = keccak256(abi.encodePacked("launch", msg.sender, _globalNonce++));
        
        // Require timelock for this critical operation
        if (_operationTimelocks[operationId] == 0) {
            _operationTimelocks[operationId] = block.timestamp + TIMELOCK_DELAY;
            emit OperationScheduled(operationId, _operationTimelocks[operationId]);
            return;
        }
        
        // Check timelock elapsed
        require(block.timestamp >= _operationTimelocks[operationId], "Timelock period not elapsed");
        delete _operationTimelocks[operationId];
        
        // Execute launch
        require(address(_doveToken) != address(0), "Token address not set");
        _doveToken.launch();
    }
    
    /**
     * @dev Set charity wallet address
     * @param newCharityWallet New charity wallet address
     * @notice Requires FEE_MANAGER_ROLE
     */
    function setCharityWallet(address newCharityWallet) external nonReentrant onlyRole(FEE_MANAGER_ROLE) notLocked {
        require(address(_doveToken) != address(0), "Token address not set");
        require(newCharityWallet != address(0), "New charity wallet cannot be zero address");
        _doveToken.setCharityWallet(newCharityWallet);
    }
    
    /**
     * @dev Exclude or include an address from fees
     * @param account Address to update
     * @param excluded Whether to exclude from fees
     * @notice Requires DEFAULT_ADMIN_ROLE or FEE_MANAGER_ROLE
     */
    function excludeFromFee(address account, bool excluded) external nonReentrant notLocked {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || 
            hasRole(FEE_MANAGER_ROLE, msg.sender),
            "Caller is not authorized"
        );
        require(address(_doveToken) != address(0), "Token address not set");
        require(account != address(0), "Account cannot be zero address");
        _doveToken.setExcludedFromFee(account, excluded);
    }
    
    /**
     * @dev Set a DEX address status
     * @param dexAddress Address to set status for
     * @param dexStatus Whether the address is a DEX
     * @notice Requires DEFAULT_ADMIN_ROLE
     */
    function setDexStatus(address dexAddress, bool dexStatus) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) notLocked {
        require(address(_doveToken) != address(0), "Token address not set");
        require(dexAddress != address(0), "DEX address cannot be zero address");
        _doveToken.setDexStatus(dexAddress, dexStatus);
    }
    
    /**
     * @dev Disable early sell tax permanently (emergency function)
     * @notice Requires EMERGENCY_ADMIN_ROLE
     */
    function disableEarlySellTax() external nonReentrant onlyRole(EMERGENCY_ADMIN_ROLE) {
        require(address(_doveToken) != address(0), "Token address not set");
        _doveToken.disableEarlySellTax();
    }
    
    /**
     * @dev Disable max transaction limit permanently
     * @notice Requires DEFAULT_ADMIN_ROLE
     */
    function disableMaxTxLimit() external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) notLocked {
        // Create operation ID using nonce for uniqueness
        bytes32 operationId = keccak256(abi.encodePacked("disableMaxTxLimit", msg.sender, _globalNonce++));
        
        // Require timelock for this critical operation
        if (_operationTimelocks[operationId] == 0) {
            _operationTimelocks[operationId] = block.timestamp + TIMELOCK_DELAY;
            emit OperationScheduled(operationId, _operationTimelocks[operationId]);
            return;
        }
        
        // Check timelock elapsed
        require(block.timestamp >= _operationTimelocks[operationId], "Timelock period not elapsed");
        delete _operationTimelocks[operationId];
        
        require(address(_doveToken) != address(0), "Token address not set");
        _doveToken.disableMaxTxLimit();
    }
    
    /**
     * @dev Set token address
     * @param tokenAddress Address of the DOVE token
     * @notice Requires DEFAULT_ADMIN_ROLE
     */
    function setTokenAddress(address tokenAddress) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) notLocked {
        require(tokenAddress != address(0), "Token address cannot be zero address");
        require(address(_doveToken) == address(0), "Token address already set");
        _doveToken = IDOVE(tokenAddress);
        emit TokenAddressSet(tokenAddress);
    }
    
    /**
     * @dev Pause all token transfers
     * @notice Requires PAUSER_ROLE
     */
    function pause() external nonReentrant onlyRole(PAUSER_ROLE) {
        require(address(_doveToken) != address(0), "Token address not set");
        _doveToken.pause();
    }
    
    /**
     * @dev Unpause all token transfers
     * @notice Requires PAUSER_ROLE
     */
    function unpause() external nonReentrant onlyRole(PAUSER_ROLE) {
        require(address(_doveToken) != address(0), "Token address not set");
        _doveToken.unpause();
    }
    
    /**
     * @dev Enable security lockdown - emergency only
     * @notice Requires EMERGENCY_ADMIN_ROLE
     */
    function setSecurityLockdown(bool enabled) external nonReentrant onlyRole(EMERGENCY_ADMIN_ROLE) {
        _securityLockdown = enabled;
        emit SecurityLockdown(enabled);
    }
    
    /**
     * @dev Cancel a scheduled operation
     * @param operationId ID of operation to cancel
     * @notice Requires DEFAULT_ADMIN_ROLE
     */
    function cancelOperation(bytes32 operationId) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_operationTimelocks[operationId] != 0, "Operation not scheduled");
        delete _operationTimelocks[operationId];
        emit OperationCancelled(operationId);
    }
    
    // ================ View Functions ================
    
    /**
     * @dev Get the DOVE token address
     * @return Address of the DOVE token
     */
    function getTokenAddress() external view returns (address) {
        return address(_doveToken);
    }
}
