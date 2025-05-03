// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../interfaces/IDOVEInfo.sol";
import "../interfaces/IDOVEGovernance.sol";
import "./DOVEFees.sol";

/**
 * @title DOVEInfo
 * @dev View functions for the DOVE token ecosystem
 * Provides read-only access to token information and configuration
 */
contract DOVEInfo is IDOVEInfo {
    // ================ Constants ================
    
    // Charity fee: 0.5% (50 basis points)
    uint16 public constant CHARITY_FEE_BP = 50; // 0.5%
    
    // ================ State Variables ================
    
    // DOVE token reference
    address private _doveToken;
    
    // Fee manager reference
    DOVEFees private _feeManager;
    
    // Governance contract reference
    IDOVEGovernance private _governanceContract;
    
    // Maximum transaction amount (cached)
    uint256 private _maxTransactionAmount;
    
    // Max transaction limit enabled flag
    bool private _isMaxTxLimitEnabled = true;
    
    // Max wallet limit enabled flag
    bool private _isMaxWalletLimitEnabled = true;
    
    // Initialization flag
    bool private _initialized;
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor
     * Empty constructor - initialization happens in initialize function
     */
    constructor() {}
    
    /**
     * @dev Initialize the contract with required dependencies
     * @param doveToken DOVE token address
     * @param feeManager Fee manager address
     * @param governanceContract Governance contract address
     * @param maxTxAmount Maximum transaction amount
     * @return True if initialization was successful
     */
    function initialize(
        address doveToken,
        address feeManager,
        address governanceContract,
        uint256 maxTxAmount
    ) external returns (bool) {
        require(!_initialized, "Already initialized");
        require(doveToken != address(0), "DOVE token cannot be zero address");
        require(feeManager != address(0), "Fee manager cannot be zero address");
        require(governanceContract != address(0), "Governance cannot be zero address");
        
        _doveToken = doveToken;
        _feeManager = DOVEFees(feeManager);
        _governanceContract = IDOVEGovernance(governanceContract);
        _maxTransactionAmount = maxTxAmount;
        _isMaxTxLimitEnabled = true;
        _initialized = true;
        
        return true;
    }
    
    // ================ Modifiers ================
    
    /**
     * @dev Only allows the DOVE token to call
     */
    modifier onlyDOVE() {
        require(msg.sender == _doveToken, "Only DOVE token can call");
        _;
    }
    
    // ================ External Functions ================
    
    /**
     * @dev Update max transaction limit status
     * @param isEnabled Whether the limit is enabled
     */
    function setMaxTxLimitEnabled(bool isEnabled) external override onlyDOVE {
        _isMaxTxLimitEnabled = isEnabled;
    }
    
    /**
     * @dev Update max wallet limit status
     * @param isEnabled Whether the limit is enabled
     */
    function setMaxWalletLimitEnabled(bool isEnabled) external override onlyDOVE {
        _isMaxWalletLimitEnabled = isEnabled;
    }
    
    // ================ View Functions ================
    
    /**
     * @dev Get the charity wallet address
     * @return Address of the charity wallet
     */
    function getCharityWallet() external view override returns (address) {
        return _feeManager.getCharityWallet();
    }
    
    /**
     * @dev Get the charity fee percentage in basis points
     * @return Charity fee in basis points
     */
    function getCharityFee() external pure override returns (uint16) {
        return CHARITY_FEE_BP;
    }
    
    /**
     * @dev Get whether an address is excluded from fees
     * @param account Address to check
     * @return Whether the address is excluded from fees
     */
    function isExcludedFromFee(address account) external view override returns (bool) {
        return _feeManager.isExcludedFromFee(account);
    }
    
    /**
     * @dev Get whether an address is marked as a DEX
     * @param account Address to check
     * @return Whether the address is a DEX
     */
    function getDexStatus(address account) external view override returns (bool) {
        return _feeManager.getDexStatus(account);
    }
    
    /**
     * @dev Get the maximum transaction amount
     * @return Maximum transaction amount
     */
    function getMaxTransactionAmount() external view override returns (uint256) {
        return _isMaxTxLimitEnabled ? _maxTransactionAmount : type(uint256).max;
    }
    
    /**
     * @dev Get the admin contract address
     * @return Address of the admin contract
     */
    function getAdminContract() external view override returns (address) {
        return _governanceContract.getAdminContract();
    }
    
    /**
     * @dev Get admin update proposal details
     * @param proposalId ID of the proposal
     * @return newAdmin Proposed admin contract address
     * @return timestamp Time when proposal was created
     * @return approvalCount Number of approvals
     * @return executed Whether proposal has been executed
     */
    function getAdminUpdateProposal(uint256 proposalId) external view override returns (
        address newAdmin,
        uint256 timestamp,
        uint256 approvalCount,
        bool executed
    ) {
        return _governanceContract.getAdminUpdateProposal(proposalId);
    }
}
