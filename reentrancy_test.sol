// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title ReentrancyPatternTest
 * @dev Example contract to test reentrancy protection approaches
 */
contract ReentrancyPatternTest is ReentrancyGuard {
    mapping(address => uint256) private _balances;
    
    // Example 1: Uses nonReentrant modifier and follows checks-effects-interactions
    // This is our current approach in DOVE
    function secureTransfer(address to, uint256 amount) external nonReentrant {
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        
        // Effects - Update state
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        
        // Interactions - External calls last
        (bool success, ) = to.call{value: 0}("");
        require(success, "External call failed");
    }
    
    // Example 2: Only follows checks-effects-interactions without nonReentrant
    // This is what O3 suggests
    function transferWithoutModifier(address to, uint256 amount) external {
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        
        // Effects - Update state
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        
        // Interactions - External calls last
        (bool success, ) = to.call{value: 0}("");
        require(success, "External call failed");
    }
}
