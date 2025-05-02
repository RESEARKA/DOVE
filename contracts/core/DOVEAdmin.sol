// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../interfaces/IDOVEAdmin.sol";
import "../interfaces/IDOVEFees.sol";
import "../access/MultiSigControl.sol";

/**
 * @title DOVE Admin
 * @dev Administration contract for DOVE token with multi-signature governance
 */
contract DOVEAdmin is Ownable2Step, Pausable, IDOVEAdmin, MultiSigControl {
    // ================ State Variables ================
    
    // Fee management module - handles charity fee and early sell tax
    IDOVEFees public immutable feeManager;
    
    // Token launch status
    bool private _isTokenLaunched;
    uint256 private _launchTimestamp;
    
    // Maximum transaction limit status
    bool private _isMaxTxLimitEnabled = true;
    
    // ================ Events ================
    
    event MaxTxLimitToggled(bool isEnabled);
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor initializes the admin contract
     * @param feeManagerAddress Address of the fee manager contract
     */
    constructor(address feeManagerAddress) MultiSigControl() {
        require(feeManagerAddress != address(0), "Fee manager cannot be zero address");
        
        // Initialize fee manager
        feeManager = IDOVEFees(feeManagerAddress);
    }
    
    // ================ External View Functions ================
    
    /**
     * @dev Check if token is paused
     * @return True if token is paused
     */
    function isPaused() external view override returns (bool) {
        return paused();
    }
    
    /**
     * @dev Check if token is launched
     * @return True if token is launched
     */
    function isLaunched() external view override returns (bool) {
        return _isTokenLaunched;
    }
    
    /**
     * @dev Get the launch timestamp
     * @return Launch timestamp, 0 if not launched
     */
    function getLaunchTimestamp() external view override returns (uint256) {
        return _launchTimestamp;
    }
    
    /**
     * @dev Check if maximum transaction limit is enabled
     * @return True if maximum transaction limit is enabled
     */
    function isMaxTxLimitEnabled() external view override returns (bool) {
        return _isMaxTxLimitEnabled;
    }
    
    /**
     * @dev Get the number of required approvals for multi-signature operations
     * @return Number of required approvals
     */
    function getRequiredApprovals() external view override returns (uint256) {
        return _requiredApprovals;
    }
    
    /**
     * @dev Get the list of approvers for multi-signature operations
     * @return Array of approver addresses
     */
    function getApprovers() external view override returns (address[] memory) {
        return _approvers;
    }
    
    /**
     * @dev Check if an operation has been approved by a specific account
     * @param operation Operation to check
     * @param account Account to check
     * @return True if the operation has been approved by the account
     */
    function hasApproved(bytes32 operation, address account) external view override returns (bool) {
        return _pendingApprovals[operation][account];
    }
    
    /**
     * @dev Get the number of approvals for an operation
     * @param operation Operation to check
     * @return Number of approvals
     */
    function getApprovalCount(bytes32 operation) external view override returns (uint256) {
        return _approvalCounts[operation];
    }
    
    /**
     * @dev Check if an operation has been completed
     * @param operation Operation to check
     * @return True if the operation has been completed
     */
    function isOperationComplete(bytes32 operation) external view override returns (bool) {
        return _operationComplete[operation];
    }
    
    /**
     * @dev Get the fee manager address
     * @return Fee manager address
     */
    function getFeeManager() external view override returns (address) {
        return address(feeManager);
    }
    
    // ================ Admin Functions ================
    
    /**
     * @dev Internal implementation of token launch
     */
    function launchToken() internal {
        require(!feeManager.isLaunched(), "Token already launched");
        
        // Follow checks-effects-interactions pattern
        // Update internal state first
        _isTokenLaunched = true;
        _launchTimestamp = block.timestamp;
        
        // Make external calls after state changes
        // Any failure here will revert the entire transaction
        try feeManager._setLaunched(block.timestamp) {
            emit TokenLaunched(block.timestamp);
        } catch Error(string memory reason) {
            // Revert with the reason
            revert(string(abi.encodePacked("Failed to launch token: ", reason)));
        } catch {
            // Revert with a generic message
            revert("Failed to launch token");
        }
    }
    
    /**
     * @dev Launch the token (multi-sig required)
     */
    function launch() external onlyRole(DEFAULT_ADMIN_ROLE) requiresMultiSig(keccak256("launch")) nonReentrant {
        launchToken();
    }
    
    /**
     * @dev Pause token transfers (multi-sig required)
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) requiresMultiSig(keccak256("pause")) nonReentrant {
        _pause();
    }
    
    /**
     * @dev Unpause token transfers (multi-sig required)
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) requiresMultiSig(keccak256("unpause")) nonReentrant {
        _unpause();
    }
    
    /**
     * @dev Toggle maximum transaction limit
     * @param enabled Whether to enable the maximum transaction limit
     */
    function toggleMaxTxLimit(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) 
                             requiresMultiSig(keccak256(abi.encodePacked("toggleMaxTxLimit", enabled))) nonReentrant {
        _isMaxTxLimitEnabled = enabled;
        emit MaxTxLimitToggled(enabled);
    }
    
    /**
     * @dev Permanently disable maximum transaction limit
     */
    function disableMaxTxLimit() external onlyRole(DEFAULT_ADMIN_ROLE) 
                               requiresMultiSig(keccak256("disableMaxTxLimit")) nonReentrant {
        _isMaxTxLimitEnabled = false;
        emit MaxTxLimitDisabled();
    }
    
    /**
     * @dev Disable early sell tax permanently
     */
    function disableEarlySellTax() external onlyRole(DEFAULT_ADMIN_ROLE) 
                                 requiresMultiSig(keccak256("disableEarlySellTax")) nonReentrant {
        // Use try-catch to handle potential errors in external calls
        try feeManager._disableEarlySellTax() {
            emit EarlySellTaxDisabled();
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("Failed to disable early sell tax: ", reason)));
        } catch {
            revert("Failed to disable early sell tax");
        }
    }
    
    /**
     * @dev Update the charity wallet address
     * @param newCharityWallet New charity wallet address
     */
    function updateCharityWallet(address newCharityWallet) external onlyRole(DEFAULT_ADMIN_ROLE) 
                                requiresMultiSig(keccak256(abi.encodePacked("updateCharityWallet", newCharityWallet))) nonReentrant {
        require(newCharityWallet != address(0), "Charity wallet cannot be zero address");
        
        address oldWallet = feeManager.getCharityWallet();
        
        // Use try-catch to handle potential errors in external calls
        try feeManager._updateCharityWallet(newCharityWallet) {
            emit CharityWalletUpdated(oldWallet, newCharityWallet);
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("Failed to update charity wallet: ", reason)));
        } catch {
            revert("Failed to update charity wallet");
        }
    }
    
    /**
     * @dev Set a known DEX address
     * @param dexAddress Address of the DEX
     * @param isDex Whether the address is a DEX
     */
    function setKnownDex(address dexAddress, bool isDex) external onlyRole(DEFAULT_ADMIN_ROLE) 
                        requiresMultiSig(keccak256(abi.encodePacked("setKnownDex", dexAddress, isDex))) nonReentrant {
        // Call fee manager to set known DEX
        try feeManager._setKnownDex(dexAddress, isDex) {
            emit KnownDexUpdated(dexAddress, isDex);
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("Failed to set known DEX: ", reason)));
        } catch {
            revert("Failed to set known DEX");
        }
    }
    
    /**
     * @dev Exclude an account from fees
     * @param account Address to exclude
     * @param excluded Whether to exclude the account
     */
    function setExcludedFromFee(address account, bool excluded) external onlyRole(DEFAULT_ADMIN_ROLE) 
                               requiresMultiSig(keccak256(abi.encodePacked("setExcludedFromFee", account, excluded))) nonReentrant {
        // Call fee manager to exclude account from fees
        try feeManager._setExcludedFromFee(account, excluded) {
            emit ExcludedFromFeeUpdated(account, excluded);
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("Failed to exclude account from fees: ", reason)));
        } catch {
            revert("Failed to exclude account from fees");
        }
    }
}
