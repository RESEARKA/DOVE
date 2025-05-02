// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./DOVEMultiSigGovernance.sol";

/**
 * @title DOVE Feature Controller
 * @dev Manages token features like pause, max transaction limit, and launch
 */
abstract contract DOVEFeatureController is DOVEMultiSigGovernance {
    // ================ Events ================
    event MaxTxLimitToggled(bool isEnabled);
    
    /**
     * @dev Internal implementation of token launch
     */
    function launchToken() internal {
        require(!_feeManager.isLaunched(), "Token already launched");
        
        // Mark token as launched and record the timestamp
        _feeManager._setLaunched(block.timestamp);
        emit TokenLaunched(block.timestamp);
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
        // Call the fee manager to disable early sell tax
        _feeManager._disableEarlySellTax();
        emit EarlySellTaxDisabled();
    }
    
    /**
     * @dev Update the charity wallet address
     * @param newCharityWallet New charity wallet address
     */
    function updateCharityWallet(address newCharityWallet) external onlyRole(DEFAULT_ADMIN_ROLE) 
                                requiresMultiSig(keccak256(abi.encodePacked("updateCharityWallet", newCharityWallet))) nonReentrant {
        require(newCharityWallet != address(0), "Charity wallet cannot be zero address");
        
        address oldWallet = _feeManager.getCharityWallet();
        
        // Call fee manager to update charity wallet
        _feeManager._updateCharityWallet(newCharityWallet);
        
        emit CharityWalletUpdated(oldWallet, newCharityWallet);
    }
    
    /**
     * @dev Set a known DEX address
     * @param dexAddress Address of the DEX
     * @param isDex Whether the address is a DEX
     */
    function setKnownDex(address dexAddress, bool isDex) external onlyRole(DEFAULT_ADMIN_ROLE) 
                        requiresMultiSig(keccak256(abi.encodePacked("setKnownDex", dexAddress, isDex))) nonReentrant {
        // Call fee manager to set known DEX
        _feeManager._setKnownDex(dexAddress, isDex);
        
        emit KnownDexUpdated(dexAddress, isDex);
    }
    
    /**
     * @dev Exclude an account from fees
     * @param account Address to exclude
     * @param excluded Whether to exclude the account
     */
    function setExcludedFromFee(address account, bool excluded) external onlyRole(DEFAULT_ADMIN_ROLE) 
                               requiresMultiSig(keccak256(abi.encodePacked("setExcludedFromFee", account, excluded))) nonReentrant {
        // Call fee manager to exclude account from fees
        _feeManager._setExcludedFromFee(account, excluded);
        
        emit ExcludedFromFeeUpdated(account, excluded);
    }
}
