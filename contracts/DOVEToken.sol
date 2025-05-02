// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./core/DOVE.sol";

/**
 * @title DOVE Token
 * @dev Main entry point for the DOVE token
 * This contract provides a simple entry point to deploy the DOVE token
 * while the implementation has been modularized for better maintainability
 * 
 * Architecture Overview:
 * - core/DOVE.sol - Main token implementation with transfer logic
 * - core/DOVEAdmin.sol - Administration functionality with multi-signature support
 * - core/DOVEFees.sol - Fee management and calculation
 * - access/MultiSigControl.sol - Multi-signature operation control
 * - access/RoleManager.sol - Role-based access control with time-limited approvals
 * - utils/FeeCalculator.sol - Fee calculation library
 * - utils/StringUtils.sol - String utilities for error messages
 */
contract DOVEToken is DOVE {
    /**
     * @dev Constructor simply passes required addresses to the base implementation
     * @param adminManagerAddress Address of the admin management contract
     * @param feeManagerAddress Address of the fee management contract
     */
    constructor(
        address adminManagerAddress,
        address feeManagerAddress
    ) DOVE(adminManagerAddress, feeManagerAddress) {}
}
