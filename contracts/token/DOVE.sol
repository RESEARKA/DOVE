// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IDOVE.sol";
import "../interfaces/IDOVEAdmin.sol";
import "../interfaces/IDOVEInfo.sol";
import "../interfaces/IDOVEGovernance.sol";
import "./DOVEEvents.sol";
import "./DOVEFees.sol";
import "../utils/FeeLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DOVE Token
 * @dev ERC20 token with fee mechanics, charity fees, and governance
 */

contract DOVE is ERC20, Pausable, ReentrancyGuard, IDOVE, Ownable {
    using SafeERC20 for IERC20;

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
    IDOVEAdmin private immutable _adminContract;
    
    // Governance contract reference - handles admin updates
    IDOVEGovernance private _governanceContract;
    
    // Fee manager reference - handles fee calculations and management
    DOVEFees private immutable _feeManager;
    
    // Events contract - handles event emissions
    DOVEEvents private _eventsContract;
    
    // Info contract - handles view function delegation
    IDOVEInfo private _infoContract;
    
    // Max wallet limit enabled flag
    bool private _isMaxWalletLimitEnabled = true;
    
    // Whether all secondary contracts are set
    bool private _fullyInitialized;
    
    // Special addresses that are always exempt from fees
    mapping(address => bool) private _alwaysFeeExempt;
    
    // Mapping of addresses that are excluded from max wallet limit
    mapping(address => bool) private _isExcludedFromMaxLimit;
    
    // Address for the liquidity manager contract
    address private _liquidityManagerAddress;

    // Simple mutex to prevent re-entrant fee callbacks without incurring full ReentrancyGuard gas on every transfer
    bool private _inTransfer;

    event TokenLimitsUpdated(address indexed newTokenLimits);
    event FeeManagerUpdated(address indexed newFeeManager);
    event EventsContractUpdated(address indexed newEventsContract);
    event GovernanceContractUpdated(address indexed newGovernanceContract);
    event InfoContractUpdated(address indexed newInfoContract);
    event FullyInitialized();
    event CharityWalletUpdated(address indexed oldWallet, address indexed newWallet);
    event ExcludedFromFeeUpdated(address indexed account, bool excluded);
    event DexStatusUpdated(address indexed dexAddress, bool isDex);
    event EarlySellTaxDisabled();
    event MaxTxLimitDisabled();
    event MaxWalletLimitDisabled();

    // ================ Constructor ================
    
    /**
     * @dev Constructor - initializes the token with base dependencies
     * @param adminContract Address of the admin contract
     * @param charityWallet Initial charity wallet address
     * @param initialSupplyRecipient Address to receive the initial token supply
     */
    constructor(address adminContract, address charityWallet, address initialSupplyRecipient) 
        ERC20("DOVE", "DOVE") 
        Ownable() 
    {
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
        
        // Mark special addresses as always fee exempt
        _alwaysFeeExempt[DEAD_ADDRESS] = true;
        _alwaysFeeExempt[charityWallet] = true;
        _alwaysFeeExempt[address(this)] = true;
        
        // Self-register with admin contract
        IDOVEAdmin(adminContract).setTokenAddress(address(this));
        
        // Token starts in PAUSED state – must be launched explicitly later
        _pause();
        
        _isExcludedFromMaxLimit[address(this)] = true;
    }
    
    // ================ Initialization Functions ================
    
    /**
     * @notice Sets the addresses of secondary helper contracts (events, governance, info).
     * @param newEventsContract Address of the DOVEEvents contract.
     * @param newGovernanceContract Address of the IDOVEGovernance contract.
     * @param newInfoContract Address of the IDOVEInfo contract.
     * @dev Can only be called by the owner. Sets the _fullyInitialized flag to true.
     */
    function setSecondaryContracts(
        address newEventsContract,
        address newGovernanceContract,
        address newInfoContract
    ) external override onlyOwner {
        require(!_fullyInitialized, "Secondary contracts already set");
        require(newEventsContract != address(0), "DOVE: Events contract is zero address");
        require(newGovernanceContract != address(0), "DOVE: Governance contract is zero address");
        require(newInfoContract != address(0), "DOVE: Info contract is zero address");

        _eventsContract = DOVEEvents(newEventsContract);
        _governanceContract = IDOVEGovernance(newGovernanceContract);
        _infoContract = IDOVEInfo(newInfoContract);

        emit EventsContractUpdated(newEventsContract);
        emit GovernanceContractUpdated(newGovernanceContract);
        emit InfoContractUpdated(newInfoContract);

        if (!_fullyInitialized) {
            _fullyInitialized = true;
            emit FullyInitialized();
        }
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
    
    /**
     * @dev Restricts to fee manager contract
     */
    modifier onlyFeeManager() {
        require(msg.sender == address(_feeManager), "Only FeeManager");
        _;
    }
    
    /// @dev Prevents nested `_transfer` calls within the same TX (fee-manager callbacks)
    modifier noFeeReentry() {
        require(!_inTransfer, "Re-entry");
        _inTransfer = true;
        _;
        _inTransfer = false;
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
        emitLaunchEvent();
    }
    
    /**
     * @dev Pause the token, disabling transfers
     * @notice Can only be called by the admin contract
     */
    function pause() external override virtual onlyAdmin whenInitialized {
        _pause();
    }
    
    /**
     * @dev Unpause the token, enabling transfers
     * @notice Can only be called by the admin contract
     */
    function unpause() external override virtual onlyAdmin whenInitialized {
        _unpause();
    }
    
    /**
     * @dev Updates the charity wallet address
     * @param newCharityWallet Address of the new charity wallet
     */
    function setCharityWallet(address newCharityWallet) external override virtual onlyAdmin {
        address oldWallet = _feeManager.getCharityWallet();
        _feeManager.setCharityWallet(newCharityWallet);
        
        // Remove old wallet from always-exempt list
        _alwaysFeeExempt[oldWallet] = false;
        
        // Check if old wallet was manually excluded and remove that status too
        if (_feeManager.isExcludedFromFee(oldWallet)) {
            _feeManager.setExcludedFromFee(oldWallet, false);
        }
        
        // Add new wallet to always-exempt list
        _alwaysFeeExempt[newCharityWallet] = true;
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
        
        // Emit event
        _eventsContract.emitMaxTxLimitDisabled();
    }
    
    /**
     * @dev Disable max wallet limit permanently
     * @notice Can only be called by the admin contract
     */
    function disableMaxWalletLimit() external override virtual onlyAdmin {
        // Only execute if max wallet limit is enabled
        if (!_isMaxWalletLimitEnabled) {
            revert MaxWalletLimitAlreadyDisabled();
        }
        _isMaxWalletLimitEnabled = false;
        _eventsContract.emitMaxWalletLimitDisabled();
    }
    
    /**
     * @dev Set address exclusion from max wallet limit
     * @param account Address to set exclusion for
     * @param excluded Whether to exclude the address from the limit
     * @notice Can only be called by the admin contract
     */
    function setExcludedFromMaxWalletLimit(address account, bool excluded) external onlyAdmin {
        require(account != address(0), "Cannot set zero address");
        _isExcludedFromMaxLimit[account] = excluded;
    }
    
    /**
     * @dev Transfer fee from contract to recipient (only callable by fee manager)
     * @param from Address to deduct from
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return Whether the transfer was successful
     */
    function transferFeeFromContract(address from, address to, uint256 amount) external override(IDOVE) onlyFeeManager nonReentrant returns (bool) {
        _transfer(from, to, amount);
        return true;
    }
    
    /**
     * @dev Burn fee amount (only callable by fee manager)
     * @param from Address to deduct from
     * @param amount Amount to burn
     * @return Whether the burn was successful
     */
    function burnFeeFromContract(address from, uint256 amount) external override(IDOVE) onlyFeeManager nonReentrant returns (bool) {
        _burn(from, amount);
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
    function emitCharityWalletUpdated(address oldWallet, address newWallet) external override(IDOVE) onlyFeeManager {
        emit CharityWalletUpdated(oldWallet, newWallet);
    }
    
    /**
     * @dev Pass event emission to events contract (called by fee manager)
     */
    function emitExcludedFromFeeUpdated(address account, bool excluded) external override(IDOVE) onlyFeeManager {
        emit ExcludedFromFeeUpdated(account, excluded);
    }
    
    /**
     * @dev Pass event emission to events contract (called by fee manager)
     */
    function emitDexStatusUpdated(address dexAddress, bool dexStatus) external override(IDOVE) whenInitialized {
        if (msg.sender != address(_feeManager)) {
            revert OnlyFeeManagerCanCall();
        }
        _eventsContract.emitDexStatusUpdated(dexAddress, dexStatus);
    }
    
    /**
     * @dev Pass event emission to events contract (called by fee manager)
     */
    function emitEarlySellTaxDisabled() external override(IDOVE) onlyFeeManager {
        emit EarlySellTaxDisabled();
    }
    
    /**
     * @dev Pass event emission to events contract (called by fee manager)
     */
    function emitMaxTxLimitDisabled() external override(IDOVE) onlyFeeManager {
        _eventsContract.emitMaxTxLimitDisabled();
    }
    
    /**
     * @dev Pass event emission to events contract (called by fee manager)
     */
    function emitMaxWalletLimitDisabled() external override(IDOVE) onlyFeeManager {
        _eventsContract.emitMaxWalletLimitDisabled();
    }
    
    /**
     * @dev Pass event emission to events contract (called by fee manager)
     */
    function emitLiquidityManagerUpdated(address newManager) external override(IDOVE) onlyOwner {
        _eventsContract.emitLiquidityManagerUpdated(newManager);
    }
    
    /**
     * @dev Pass event emission to events contract (called by fee manager)
     */
    function emitTokenRecovered(address token, uint256 amount, address to) external override(IDOVE) onlyOwner {
        _eventsContract.emitTokenRecovered(token, amount, to);
    }
    
    /**
     * @dev Set a new liquidity manager address
     * @param _newLiquidityManager New liquidity manager address
     */
    function setLiquidityManager(address _newLiquidityManager) external override virtual onlyAdmin whenInitialized {
        require(_newLiquidityManager != address(0), "DOVE: Zero address for liquidity manager");
        address oldManager = _liquidityManagerAddress;
        _liquidityManagerAddress = _newLiquidityManager;
        
        _alwaysFeeExempt[_newLiquidityManager] = true; // Liquidity manager is typically fee exempt
        if (oldManager != address(0) && oldManager != _feeManager.getCharityWallet()) { // Don't remove exemption if it was also the charity wallet or another critical exempt address
            _alwaysFeeExempt[oldManager] = false; 
        }
        
        _eventsContract.emitLiquidityManagerUpdated(_newLiquidityManager);
    }

    /**
     * @dev Set an address as exempt or not exempt from fees (IDOVE interface compliance)
     * @param account Address to update
     * @param exempt Whether the address should be exempt from fees
     */
    function setFeeExemption(address account, bool exempt) external override virtual onlyAdmin whenInitialized {
        // Calls the existing internal logic, ensuring IDOVE interface is met.
        // The setExcludedFromFee function is already part of DOVE's admin capabilities (likely from IDOVEAdmin)
        _feeManager.setExcludedFromFee(account, exempt);
    }

    /**
     * @dev Recover any ERC20 tokens accidentally sent to this contract
     * @param token The address of the ERC20 token to recover
     * @param amount The amount of tokens to recover
     * @param to The address to send recovered tokens to
     */
    function recoverToken(address token, uint256 amount, address to) external override virtual onlyAdmin whenInitialized {
        require(token != address(this), "DOVE: Cannot recover native DOVE token with this function");
        require(to != address(0), "DOVE: Recovery address cannot be the zero address");
        require(amount > 0, "DOVE: Recovery amount must be greater than zero");

        // Use SafeERC20 to transfer and handle non-standard tokens safely
        IERC20(token).safeTransfer(to, amount);
        _eventsContract.emitTokenRecovered(token, amount, to);
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
    
    /// @notice Returns true if an account is permanently fee-exempt (dead address, charity, etc.)
    /// @param account Address to query
    /// @return True if the address is always exempt from fees
    function isAlwaysFeeExempt(address account) external view override(IDOVE) returns (bool) {
        // Check dedicated exempt mapping, always exempt the token contract itself
        return _alwaysFeeExempt[account] || account == address(this);
    }
    
    /// @notice Exposes current paused state to external callers (IDOVE & Pausable override)
    function paused() public view override(IDOVE, Pausable) returns (bool) {
        return super.paused();
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
    ) internal override whenNotPaused noFeeReentry {
        if (sender == address(0)) {
            revert ZeroAddress();
        }
        if (recipient == address(0)) {
            revert ZeroAddress();
        }
        
        // Get max transaction amount from DOVEInfo instead of using local state
        // This ensures that when limits are disabled in DOVEInfo, they are immediately reflected here
        uint256 currentMaxTxAmount = _fullyInitialized ? _infoContract.getMaxTransactionAmount() : _maxTransactionAmount;
        if (amount > currentMaxTxAmount) {
            revert TransferExceedsMaxAmount();
        }
        
        // Enforce max wallet limit if enabled
        if (_isMaxWalletLimitEnabled) {
            // Skip limit for transfers to/from DEAD_ADDRESS or to charity wallet
            bool isExemptFromWalletLimit = 
                recipient == DEAD_ADDRESS || 
                recipient == _feeManager.getCharityWallet() ||
                recipient == address(this) || 
                _isExcludedFromMaxLimit[recipient];
                
            if (!isExemptFromWalletLimit) {
                uint256 recipientBalance = balanceOf(recipient);
                uint256 maxWalletAmount = totalSupply() / 100; // 1% of total supply
                
                // Check that recipient's new balance won't exceed max wallet limit
                if (recipientBalance + amount > maxWalletAmount) {
                    revert TransferExceedsMaxWalletLimit();
                }
            }
        }
        
        // Handle tiny transfers to prevent dust accumulation due to integer division
        // For the charity fee of 0.5%, any amount less than (10000/50)+1 will result in 0 fee
        uint256 minFeeableAmount = (FeeLibrary.BASIS_POINTS / FeeLibrary.CHARITY_FEE) + 1;
        if (amount < minFeeableAmount) {
            // Transfer without applying fees for tiny amounts
            super._transfer(sender, recipient, amount);
            return;
        }
        
        // Process fees through fee manager
        uint256 netAmount = _feeManager.processFees(sender, recipient, amount);
        
        // Transfer the net amount
        super._transfer(sender, recipient, netAmount);
    }
    
    /**
     * @dev See {ERC20-transfer}.
     * Requirements:
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public override(ERC20, IERC20) whenNotPaused returns (bool) {
        return super.transfer(to, amount);
    }
    
    /**
     * @dev See {ERC20-transferFrom}.
     * Emits an {Approval} event indicating the updated allowance.
     * This is not emitted by {_transfer} and must be emitted by transferFrom implementations.
     * Requirements:
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public override(ERC20, IERC20) whenNotPaused returns (bool) {
        return super.transferFrom(from, to, amount);
    }
    
    /**
     * @dev Returns true if the contract is paused, false otherwise.
     * This overrides the Pausable.paused() function to also conform to IDOVE interface.
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
    error TransferExceedsMaxWalletLimit();
    error MaxWalletLimitAlreadyDisabled();
    
    // Allow contract to receive Ether
    receive() external payable {}
    fallback() external payable {}
    
    function emitLaunchEvent() internal whenNotPaused {
        _eventsContract.emitLaunch(block.timestamp);
    }
}
