// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./DOVEMultiSigGovernance.sol";
import "../interfaces/IDOVEAdmin.sol";

/**
 * @title DOVE Feature Controller
 * @dev Controls token features like pause, max tx limit, etc.
 */
abstract contract DOVEFeatureController is DOVEMultiSigGovernance, IDOVEAdmin {
    // Role identifier for pauser role
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Flag for permanently disabling max tx limit
    bool internal _maxTxLimitPermanentlyDisabled;

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
     * @dev Launch the token
     * This function triggers the token launch process in the fee manager
     */
    function launch() public virtual onlyRole(DEFAULT_ADMIN_ROLE) requiresMultiSig(keccak256("launch")) nonReentrant {
        launchToken();
    }
    
    /**
     * @dev Pause all token transfers (direct call - no multi-sig required)
     * This provides a rapid response mechanism for emergencies
     */
    function pause() external virtual onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause all token transfers (requires multi-sig approval)
     */
    function unpause() external virtual onlyRole(DEFAULT_ADMIN_ROLE) requiresMultiSig(keccak256("unpause")) nonReentrant {
        _unpause();
    }
    
    /**
     * @dev Toggle the maximum transaction limit
     * @param enabled Whether the limit is enabled
     */
    function setMaxTxLimit(bool enabled) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _isMaxTxLimitEnabled = enabled;
        emit MaxTxLimitToggled(enabled);
    }
    
    /**
     * @dev Permanently disable the max transaction limit
     * This is a one-way operation that cannot be reversed
     */
    function disableMaxTxLimit() external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _isMaxTxLimitEnabled = false;
        _maxTxLimitPermanentlyDisabled = true;
        emit MaxTxLimitDisabled();
    }
    
    /**
     * @dev Permanently disable early sell tax
     * This is a one-way operation that cannot be reversed
     */
    function disableEarlySellTax() external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _feeManager.disableEarlySellTax();
        emit EarlySellTaxDisabled();
    }
    
    /**
     * @dev Update the charity wallet address
     * @param newCharityWallet New charity wallet address
     */
    function updateCharityWallet(address newCharityWallet) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newCharityWallet != address(0), "Charity wallet cannot be zero address");
        address oldWallet = _feeManager.getCharityWallet();
        _feeManager.updateCharityWallet(newCharityWallet);
        emit CharityWalletUpdated(oldWallet, newCharityWallet);
    }
    
    /**
     * @dev Set an address as a known DEX
     * @param dexAddress Address to update
     * @param isDex Whether the address is a DEX
     */
    function setDexStatus(address dexAddress, bool isDex) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _feeManager.setDexStatus(dexAddress, isDex);
        emit KnownDexUpdated(dexAddress, isDex);
    }
    
    /**
     * @dev Exclude or include an address from fees
     * @param account Address to update
     * @param excluded Whether the address is excluded from fees
     */
    function excludeFromFee(address account, bool excluded) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _feeManager.excludeFromFee(account, excluded);
        emit ExcludedFromFeeUpdated(account, excluded);
    }

    // Override hasRole to resolve conflict between AccessControl (via DOVEMultiSigGovernance) and IDOVEAdmin
    function hasRole(bytes32 role, address account) public view virtual override(AccessControl, IDOVEAdmin) returns (bool) {
        return super.hasRole(role, account);
    }
 }
