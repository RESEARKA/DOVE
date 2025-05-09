// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title MockAdmin
 * @dev Minimal stub implementing `setTokenAddress` for the DOVE constructor during tests.
 */
contract MockAdmin {
    address public tokenAddress;

    function setTokenAddress(address _token) external returns (bool) {
        tokenAddress = _token;
        return true;
    }

    // Helper to call unpause on DOVE token (for tests)
    function callUnpause(address token) external {
        IDOVE(token).unpause();
    }

    // Stub for IDOVEInfo
    function getMaxTransactionAmount() external pure returns (uint256) {
        return type(uint256).max / 2; // large value for tests
    }
}

interface IDOVE {
    function unpause() external;
}
