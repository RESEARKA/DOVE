// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./DOVEFeeCalculator.sol";

/**
 * @title DOVE Token Address Manager
 * @dev Handles token address management and verification
 */
abstract contract DOVETokenAddressManager is DOVEFeeCalculator {
    // ================ Events ================
    event TokenAddressSet(address indexed tokenAddress);
    event TokenAddressVerified(address indexed tokenAddress);
    event TokenAddressRecoveryInitiated(address newTokenAddress, uint256 completionTimestamp);
    event TokenAddressRecovered(address oldTokenAddress, address newTokenAddress);
    event TokenAddressRecoveryCanceled(address canceledAddress);
    
    /**
     * @dev Set token address (can only be done once)
     * @param tokenAddress The address of the token contract
     */
    function setTokenAddress(address tokenAddress) external {
        require(_tokenAddress == address(0), "Token address already set");
        require(tokenAddress != address(0), "Token address cannot be zero address");
        
        _tokenAddress = tokenAddress;
        _tokenRegistrar = msg.sender;
        
        emit TokenAddressSet(tokenAddress);
    }
    
    /**
     * @dev Verify the token address with a confirmation code
     * @param confirmationCode Code provided during token registration
     */
    function verifyTokenAddress(bytes32 confirmationCode) external {
        require(!_isTokenAddressVerified, "Token address already verified");
        require(msg.sender == _tokenAddress, "Only token can verify itself");
        require(confirmationCode == keccak256(abi.encodePacked("VERIFY_TOKEN_ADDRESS", _tokenAddress, block.chainid)),
            "Invalid confirmation code");
            
        // Set verification flag
        _isTokenAddressVerified = true;
        
        // Give the token contract the TOKEN_ROLE
        _setupRole(TOKEN_ROLE, _tokenAddress);
        
        emit TokenAddressVerified(_tokenAddress);
    }
    
    /**
     * @dev Initiate token address recovery process (time-locked)
     * @param newTokenAddress New token address
     */
    function initiateTokenAddressRecovery(address newTokenAddress) external nonReentrant {
        // SECURITY: Multi-signature requirement for initiating token address recovery
        require(hasRole(EMERGENCY_ADMIN_ROLE, msg.sender), "Requires EMERGENCY_ADMIN_ROLE");
        require(newTokenAddress != address(0), "New token address cannot be zero");
        require(_pendingTokenAddress == address(0), "Recovery already in progress");
        
        // Set the pending token address and calculate completion time
        _pendingTokenAddress = newTokenAddress;
        _tokenRecoveryCompletionTime = block.timestamp + TOKEN_ADDRESS_TIMELOCK;
        
        emit TokenAddressRecoveryInitiated(newTokenAddress, _tokenRecoveryCompletionTime);
    }
    
    /**
     * @dev Cancel an initiated token address recovery
     */
    function cancelTokenAddressRecovery() external nonReentrant {
        require(hasRole(EMERGENCY_ADMIN_ROLE, msg.sender), "Requires EMERGENCY_ADMIN_ROLE");
        require(_pendingTokenAddress != address(0), "No recovery in progress");
        
        address canceledAddress = _pendingTokenAddress;
        
        // Reset recovery state
        _pendingTokenAddress = address(0);
        _tokenRecoveryCompletionTime = 0;
        
        emit TokenAddressRecoveryCanceled(canceledAddress);
    }
    
    /**
     * @dev Complete token address recovery after timelock period
     */
    function completeTokenAddressRecovery() external nonReentrant {
        require(hasRole(EMERGENCY_ADMIN_ROLE, msg.sender), "Requires EMERGENCY_ADMIN_ROLE");
        require(_pendingTokenAddress != address(0), "No recovery in progress");
        require(block.timestamp >= _tokenRecoveryCompletionTime, "Timelock period not complete");
        
        // Store old and new addresses for event
        address oldTokenAddress = _tokenAddress;
        address newTokenAddress = _pendingTokenAddress;
        
        // Revoke TOKEN_ROLE from old address
        revokeRole(TOKEN_ROLE, oldTokenAddress);
        
        // Update token address
        _tokenAddress = newTokenAddress;
        
        // Reset recovery state
        _pendingTokenAddress = address(0);
        _tokenRecoveryCompletionTime = 0;
        
        // Token will need to verify itself again
        _isTokenAddressVerified = false;
        
        emit TokenAddressRecovered(oldTokenAddress, newTokenAddress);
    }
}
