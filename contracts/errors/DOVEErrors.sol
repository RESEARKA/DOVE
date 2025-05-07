// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * Centralized error definitions for DOVE token contracts
 */

// Base errors shared across contracts
error ZeroAddress();
error AlreadyInitialized();
error NotInitialized();
error NotAdmin();
error AlreadyLaunched();
error TransferExceedsMaxAmount();
error OnlyFeeManagerCanCall();
error TransferExceedsMaxWalletLimit();
error MaxWalletLimitAlreadyDisabled();

// Fee-specific errors
error FeesNotDOVEToken();
error FeesZeroAddressNotAllowed();
error FeesTokenAlreadyLaunched();
error FeesEarlySellTaxAlreadyDisabled();

// Admin-specific errors
error TestFunctionDisabled();
