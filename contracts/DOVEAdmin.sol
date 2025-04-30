// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IDOVEAdmin.sol";
import "./interfaces/IDOVE.sol";
import "./DOVEFees.sol";

/**
 * @title DOVE Admin Functions
 * @dev Implementation of admin functionality for DOVE token
 */
contract DOVEAdmin is Ownable2Step, Pausable, IDOVEAdmin {
    
    // ================ State Variables ================
    
    // Flag to control if max transaction limit is enabled
    bool private _isMaxTxLimitEnabled = true;
    
    // Fee management module
    DOVEFees private immutable _feeManager;
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor initializes admin module with fee manager
     * @param feeManager Address of the DOVEFees contract
     */
    constructor(DOVEFees feeManager) {
        require(address(feeManager) != address(0), "Fee manager cannot be zero address");
        _feeManager = feeManager;
    }
    
    // ================ External Functions ================
    
    /**
     * @dev See {IDOVEAdmin-launch}
     */
    function launch() external onlyOwner {
        require(!_feeManager.isLaunched(), "Token already launched");
        _feeManager._setLaunched(block.timestamp);
        emit TokenLaunched(block.timestamp);
    }
    
    /**
     * @dev See {IDOVEAdmin-pause}
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev See {IDOVEAdmin-unpause}
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev See {IDOVEAdmin-setDexStatus}
     */
    function setDexStatus(address dexAddress, bool isDex) external onlyOwner {
        require(dexAddress != address(0), "Cannot set zero address");
        _feeManager._setKnownDex(dexAddress, isDex);
        emit DexStatusUpdated(dexAddress, isDex);
    }
    
    /**
     * @dev See {IDOVEAdmin-excludeFromFee}
     */
    function excludeFromFee(address account, bool excluded) external onlyOwner {
        require(account != address(0), "Cannot exclude zero address");
        _feeManager._setExcludedFromFee(account, excluded);
        emit ExcludeFromFee(account, excluded);
    }
    
    /**
     * @dev See {IDOVEAdmin-updateCharityWallet}
     */
    function updateCharityWallet(address newCharityWallet) external onlyOwner {
        address oldWallet = _feeManager.getCharityWallet();
        _feeManager._updateCharityWallet(newCharityWallet);
        emit CharityWalletUpdated(oldWallet, newCharityWallet);
    }
    
    /**
     * @dev See {IDOVEAdmin-updateTaxRateDurations}
     */
    function updateTaxRateDurations(
        uint256 day1,
        uint256 day2,
        uint256 day3
    ) external onlyOwner {
        _feeManager._updateTaxRateDurations(day1, day2, day3);
        emit TaxDurationsUpdated(day1, day2, day3);
    }
    
    /**
     * @dev See {IDOVEAdmin-disableEarlySellTax}
     */
    function disableEarlySellTax() external onlyOwner {
        require(_feeManager.isEarlySellTaxEnabled(), "Early sell tax already disabled");
        _feeManager._disableEarlySellTax();
        emit EarlySellTaxDisabled();
    }
    
    /**
     * @dev See {IDOVEAdmin-disableMaxTxLimit}
     */
    function disableMaxTxLimit() external onlyOwner {
        require(_isMaxTxLimitEnabled, "Max tx limit already disabled");
        _isMaxTxLimitEnabled = false;
        emit MaxTxLimitDisabled();
    }
    
    /**
     * @dev See {IDOVEAdmin-isMaxTxLimitEnabled}
     */
    function isMaxTxLimitEnabled() external view returns (bool) {
        return _isMaxTxLimitEnabled;
    }
    
    /**
     * @dev See {IDOVEAdmin-isPaused}
     */
    function isPaused() external view returns (bool) {
        return paused();
    }
}
