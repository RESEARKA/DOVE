// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title DOVEErrors
 * @dev Centralized error definitions for DOVE token contracts
 * Using custom errors for gas efficiency and better error reporting
 */
library DOVEErrors {
    // Base errors
    error ZeroAddress();
    error AlreadyInitialized();
    error NotInitialized();
    error NotAuthorized();
    error TransferFailed();
    error InvalidAmount();
    error InvalidAddress();
    
    // DOVEv3 specific errors
    error CannotRecoverDOVE();
    error SlippageExceeded();
    error PoolInitializationFailed();
    error LiquidityAdditionFailed();
    error PoolDoesNotExist();
    error IncorrectTokenOrder();
    error InsufficientLiquidity();
    error PositionNotOwned();
    error MaxFeeExceeded();
    
    // Transfer related errors
    error TransferFromZeroAddress();
    error TransferToZeroAddress();
    error TransferAmountExceedsBalance();
}
