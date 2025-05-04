// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../interfaces/IDOVE.sol";
import "../interfaces/IDOVEAdmin.sol";
import "../interfaces/IDOVEInfo.sol";
import "../interfaces/IDOVEGovernance.sol";
import "./DOVEEvents.sol";
import "./DOVEFees.sol";

/**
 * @title DOVE Token
 * @dev ERC20 token with fee mechanics, charity fees, and governance
 */

contract DOVE is ERC20, AccessControl, Pausable, ReentrancyGuard, IDOVE {
    // ================ Constants ================
    
    // Total supply: 100 billion tokens (100,000,000,000 with 18 decimals)
    uint256 public constant TOTAL_SUPPLY = 100_000_000_000 * 10**18;
    
    // Maximum transaction amount: 1% of total supply
    uint256 private immutable _maxTransactionAmount;
    
    // Charity fee: 0.5% (50 basis points)
    uint16 public constant CHARITY_FEE_BP = 50; // 0.5%
    
    // Dead address for burn
    address private constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    
    // ================ State Variables ================
    
    // Admin contract reference - handles administrative functions
    IDOVEAdmin private _adminContract;
    
    // Governance contract reference - handles admin updates
    IDOVEGovernance private _governanceContract;
    
    // Fee manager reference - handles fee calculations and management
    DOVEFees private _feeManager;
    
    // Events contract - handles event emissions
    DOVEEvents private _eventsContract;
    
    // Info contract - handles view function delegation
    IDOVEInfo private _infoContract;
    
    // Max wallet limit enabled flag
    bool private _isMaxWalletLimitEnabled = true;
    
    // Whether all secondary contracts are set
    bool private _fullyInitialized;
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor - initializes the token with base dependencies
     * @param adminContract Address of the admin contract
     * @param charityWallet Initial charity wallet address
     * @param initialSupplyRecipient Address to receive the initial token supply
     */
    constructor(address adminContract, address charityWallet, address initialSupplyRecipient) ERC20("DOVE", "DOVE") {
        if (adminContract == address(0)) {
            revert ZeroAddress();
        }
        if (charityWallet == address(0)) {
            revert ZeroAddress();
        }
        if (initialSupplyRecipient == address(0)) {
            revert ZeroAddress();
        }
        
        // Set admin contract
        _adminContract = IDOVEAdmin(adminContract);
        
        // Calculate max transaction amount (1% of total supply)
        _maxTransactionAmount = TOTAL_SUPPLY / 100;
        
        // Create and set up fee manager
        _feeManager = new DOVEFees(address(this), charityWallet);
        
        // Mint total supply to the specified recipient (not always deployer)
        _mint(initialSupplyRecipient, TOTAL_SUPPLY);
        
        // Self-register with admin contract
        IDOVEAdmin(adminContract).setTokenAddress(address(this));
        
        // Token starts in PAUSED state – must be launched explicitly later
        _pause();
    }
    
    // ================ Initialization Functions ================
    
    /**
     * @dev Set event and governance contracts
     * @param eventsContract Address of events contract
     * @param governanceContract Address of governance contract
     * @param infoContract Address of info contract
     * @return True if initialization was successful
     */
    function setSecondaryContracts(
        address eventsContract,
        address governanceContract,
        address infoContract
    ) external returns (bool) {
        if (msg.sender != address(_adminContract)) {
            revert NotAdmin();
        }
        if (_fullyInitialized) {
            revert AlreadyInitialized();
        }
        if (eventsContract == address(0)) {
            revert ZeroAddress();
        }
        if (governanceContract == address(0)) {
            revert ZeroAddress();
        }
        if (infoContract == address(0)) {
            revert ZeroAddress();
        }
        
        _eventsContract = DOVEEvents(eventsContract);
        _governanceContract = IDOVEGovernance(governanceContract);
        _infoContract = IDOVEInfo(infoContract);
        _fullyInitialized = true;
        
        return true;
    }
    
    /**
     * @dev Check if the contract is fully initialized
     * @return Whether all dependencies are set
     */
    function isFullyInitialized() external view returns (bool) {
        return _fullyInitialized;
    }
    
    /**
     * @dev Get fee manager address
     * @return Address of the fee manager
     */
    function getFeeManager() external view returns (address) {
        return address(_feeManager);
    }
    
    // ================ Modifiers ================
    
    /**
     * @dev Restricts function to admin contract
     */
    modifier onlyAdmin() {
        if (msg.sender != address(_adminContract)) {
            revert NotAdmin();
        }
        _;
    }
    
    /**
     * @dev Ensures all contracts are initialized
     */
    modifier whenInitialized() {
        if (!_fullyInitialized) {
            revert NotInitialized();
        }
        _;
    }
    
    // ================ External Functions ================
    
    /**
     * @dev Launch the token, enabling transfers
     * @notice Can only be called by the admin contract
     */
    function launch() external override onlyAdmin whenInitialized {
        if (!paused()) {
            revert AlreadyLaunched();
        }
        
        // 1. Remember the launch for the fee-manager (only once)
        _feeManager.recordLaunch();
        
        // 2. Enable transfers
        _unpause();
        
        // 3. Emit ecosystem event
        _eventsContract.emitLaunch(block.timestamp);
    }
    
    /**
     * @dev Pause the token, disabling transfers
     * @notice Can only be called by the admin contract
     */
    function pause() external override onlyAdmin whenInitialized {
        _pause();
    }
    
    /**
     * @dev Unpause the token, enabling transfers
     * @notice Can only be called by the admin contract
     */
    function unpause() external override onlyAdmin whenInitialized {
        _unpause();
    }
    
    /**
     * @dev Set charity wallet address
     * @param newCharityWallet New charity wallet address
     * @notice Can only be called by the admin contract
     */
    function setCharityWallet(address newCharityWallet) external override onlyAdmin {
        _feeManager.setCharityWallet(newCharityWallet);
    }
    
    /**
     * @dev Set an address as excluded or included from fees
     * @param account Address to update
     * @param excluded Whether to exclude from fees
     * @notice Can only be called by the admin contract
     */
    function setExcludedFromFee(address account, bool excluded) external override onlyAdmin {
        _feeManager.setExcludedFromFee(account, excluded);
    }
    
    /**
     * @dev Set a DEX address status
     * @param dexAddress Address to set status for
     * @param dexStatus Whether the address is a DEX
     * @notice Can only be called by the admin contract
     */
    function setDexStatus(address dexAddress, bool dexStatus) external override onlyAdmin {
        _feeManager.setDexStatus(dexAddress, dexStatus);
    }
    
    /**
     * @dev Disable early sell tax permanently
     * @notice Can only be called by the admin contract
     */
    function disableEarlySellTax() external override onlyAdmin {
        _feeManager.disableEarlySellTax();
    }
    
    /**
     * @dev Disable max transaction limit permanently
     * @notice Can only be called by the admin contract
     */
    function disableMaxTxLimit() external override onlyAdmin whenInitialized {
        // DOVEInfo is the single source of truth, so we only check there
        // This ensures the same state is used in both checks and enforcements
        bool isEnabled = _infoContract.getMaxTransactionAmount() != type(uint256).max;
        if (!isEnabled) {
            revert AlreadyInitialized();
        }
        
        // Update DOVEInfo only - remove dependence on local state
        _infoContract.setMaxTxLimitEnabled(false);
        
        // Emit event
        _eventsContract.emitMaxTxLimitDisabled();
    }
    
    /**
     * @dev Disable max wallet limit permanently
     */
    function disableMaxWalletLimit() external override onlyAdmin whenInitialized {
        if (!_isMaxWalletLimitEnabled) {
            revert AlreadyInitialized();
        }
        _isMaxWalletLimitEnabled = false;
        _infoContract.setMaxWalletLimitEnabled(false);
        emit MaxWalletLimitDisabled();
    }
    
    /**
     * @dev Transfer fee from contract to recipient (only callable by fee manager)
     * @param from Address to deduct from
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return Whether the transfer was successful
     */
    function transferFeeFromContract(address from, address to, uint256 amount) external override returns (bool) {
        if (msg.sender != address(_feeManager)) {
            revert OnlyFeeManagerCanCall();
        }
        
        // Transfer the fee
        _transfer(from, to, amount);
        return true;
    }
    
    /**
     * @dev Burn fee amount (only callable by fee manager)
     * @param from Address to deduct from
     * @param amount Amount to burn
     * @return Whether the burn was successful
     */
    function burnFeeFromContract(address from, uint256 amount) external override returns (bool) {
        if (msg.sender != address(_feeManager)) {
            revert OnlyFeeManagerCanCall();
        }
        
        // Burn by transferring to dead address
        _transfer(from, DEAD_ADDRESS, amount);
        return true;
    }
    
    /**
     * @dev Forward admin update proposal to governance contract
     * @param newAdminContract Address of the new admin contract
     * @return proposalId ID of the created proposal
     */
    function proposeAdminUpdate(address newAdminContract) external onlyAdmin whenInitialized returns (uint256) {
        return _governanceContract.proposeAdminUpdate(newAdminContract);
    }
    
    /**
     * @dev Forward admin update approval to governance contract
     * @param proposalId ID of the proposal to approve
     */
    function approveAdminUpdate(uint256 proposalId) external onlyAdmin whenInitialized {
        _governanceContract.approveAdminUpdate(proposalId);
    }
    
    /**
     * @dev Pass event emission to events contract (called by fee manager)
     */
    function emitCharityWalletUpdated(address oldWallet, address newWallet) external override whenInitialized {
        if (msg.sender != address(_feeManager)) {
            revert OnlyFeeManagerCanCall();
        }
        _eventsContract.emitCharityWalletUpdated(oldWallet, newWallet);
    }
    
    /**
     * @dev Pass event emission to events contract (called by fee manager)
     */
    function emitExcludedFromFeeUpdated(address account, bool excluded) external override whenInitialized {
        if (msg.sender != address(_feeManager)) {
            revert OnlyFeeManagerCanCall();
        }
        _eventsContract.emitExcludedFromFeeUpdated(account, excluded);
    }
    
    /**
     * @dev Pass event emission to events contract (called by fee manager)
     */
    function emitDexStatusUpdated(address dexAddress, bool dexStatus) external override whenInitialized {
        if (msg.sender != address(_feeManager)) {
            revert OnlyFeeManagerCanCall();
        }
        _eventsContract.emitDexStatusUpdated(dexAddress, dexStatus);
    }
    
    /**
     * @dev Pass event emission to events contract (called by fee manager)
     */
    function emitEarlySellTaxDisabled() external override whenInitialized {
        if (msg.sender != address(_feeManager)) {
            revert OnlyFeeManagerCanCall();
        }
        _eventsContract.emitEarlySellTaxDisabled();
    }
    
    // ================ View Function Proxies (for API compatibility) ================
    
    /**
     * @dev Get the charity wallet address
     * @return Address of the charity wallet
     */
    function getCharityWallet() external view returns (address) {
        if (!_fullyInitialized) {
            return _feeManager.getCharityWallet();
        }
        return _infoContract.getCharityWallet();
    }
    
    /**
     * @dev Get the charity fee percentage in basis points
     * @return Charity fee in basis points
     */
    function getCharityFee() external pure returns (uint16) {
        return CHARITY_FEE_BP;
    }
    
    /**
     * @dev Get whether an address is excluded from fees
     * @param account Address to check
     * @return Whether the address is excluded from fees
     */
    function isExcludedFromFee(address account) external view returns (bool) {
        if (!_fullyInitialized) {
            return _feeManager.isExcludedFromFee(account);
        }
        return _infoContract.isExcludedFromFee(account);
    }
    
    /**
     * @dev Get whether an address is marked as a DEX
     * @param account Address to check
     * @return Whether the address is a DEX
     */
    function getDexStatus(address account) external view returns (bool) {
        if (!_fullyInitialized) {
            return _feeManager.getDexStatus(account);
        }
        return _infoContract.getDexStatus(account);
    }
    
    /**
     * @dev Get the maximum transaction amount
     * @return Maximum transaction amount
     */
    function getMaxTransactionAmount() external view returns (uint256) {
        if (!_fullyInitialized) {
            return _maxTransactionAmount;
        }
        return _infoContract.getMaxTransactionAmount();
    }
    
    /**
     * @dev Get the admin contract address
     * @return Address of the admin contract
     */
    function getAdminContract() external view returns (address) {
        if (!_fullyInitialized) {
            return address(_adminContract);
        }
        return _infoContract.getAdminContract();
    }
    
    /**
     * @dev Get admin update proposal details
     * @param proposalId ID of the proposal
     * @return newAdmin Proposed admin contract address
     * @return timestamp Time when proposal was created
     * @return approvalCount Number of approvals
     * @return executed Whether proposal has been executed
     */
    function getAdminUpdateProposal(uint256 proposalId) external view returns (
        address newAdmin,
        uint256 timestamp,
        uint256 approvalCount,
        bool executed
    ) {
        if (!_fullyInitialized) {
            return (address(0), 0, 0, false);
        }
        return _infoContract.getAdminUpdateProposal(proposalId);
    }
    
    /**
     * @dev ERC20 _transfer override
     * @param sender Sender address
     * @param recipient Recipient address
     * @param amount Amount to transfer
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override whenNotPaused {
        if (sender == address(0)) {
            revert ZeroAddress();
        }
        if (recipient == address(0)) {
            revert ZeroAddress();
        }
        
        // Get max transaction amount from DOVEInfo instead of using local state
        // This ensures that when limits are disabled in DOVEInfo, they are immediately reflected here
        uint256 maxAmount = _infoContract.getMaxTransactionAmount();
        if (amount > maxAmount) {
            revert TransferExceedsMaxAmount();
        }
        
        // Process fees through fee manager
        uint256 netAmount = _feeManager.processFees(sender, recipient, amount);
        
        // Transfer the net amount
        super._transfer(sender, recipient, netAmount);
    }
    
    /**
     * @dev Override ERC20 transfer function to add reentrancy protection
     * @param to Address to transfer to
     * @param amount Amount to transfer
     * @return Success indicator
     */
    function transfer(address to, uint256 amount) public override nonReentrant returns (bool) {
        return super.transfer(to, amount);
    }
    
    /**
     * @dev Override ERC20 transferFrom function to add reentrancy protection
     * @param from Address to transfer from
     * @param to Address to transfer to 
     * @param amount Amount to transfer
     * @return Success indicator
     */
    function transferFrom(address from, address to, uint256 amount) public override nonReentrant returns (bool) {
        return super.transferFrom(from, to, amount);
    }
    
    /**
     * @dev Returns whether the token is paused
     * @return Whether the token is paused
     */
    function paused() public view override(Pausable, IDOVE) returns (bool) {
        return super.paused();
    }
    
    /**
     * @dev ERC20 _beforeTokenTransfer override
     * @param from Address to deduct from
     * @param to Recipient address
     * @param amount Amount to transfer
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
    
    // Custom errors - more gas efficient than require strings
    error ZeroAddress();
    error AlreadyInitialized();
    error NotInitialized();
    error NotAdmin();
    error AlreadyLaunched();
    error TransferExceedsMaxAmount();
    error OnlyFeeManagerCanCall();
}
