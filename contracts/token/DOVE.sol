// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IDOVE.sol";
import "../interfaces/IDOVEAdmin.sol";
import "./DOVEFees.sol";

/**
 * @title DOVE Token
 * @dev Implementation of the DOVE token with charity fee and early-sell tax mechanisms
 * 
 * IMPORTANT FEE STRUCTURE NOTICE:
 * This token implements two types of fees that affect transfer amounts:
 * 1. Charity Fee (0.5%): Applied to all transfers except excluded addresses
 *    - Fee is sent to a designated charity wallet
 * 2. Early Sell Tax (5% to 0%): Applied only when selling to DEX in first 72 hours
 *    - Tax rate decreases over time (5%, 3%, 1%, then 0%)
 *    - Tax amount is burned from supply
 * 
 * Users should be aware that the amount received by the recipient will be
 * less than the amount sent by the sender due to these fees.
 */
contract DOVE is ERC20, AccessControl, Pausable, ReentrancyGuard, IDOVE {
    // ================ Constants ================
    
    // Total supply: 100 billion tokens (100,000,000,000 with 18 decimals)
    uint256 public constant TOTAL_SUPPLY = 100_000_000_000 * 10**18;
    
    // Maximum transaction amount: 1% of total supply
    uint256 private immutable _maxTransactionAmount;
    
    // Charity fee: 0.5% (50 basis points)
    uint16 public constant CHARITY_FEE_BP = 50; // 0.5%
    
    // ================ State Variables ================
    
    // Admin contract reference - handles administrative functions
    IDOVEAdmin private _adminContract;
    
    // Fee manager - handles all fee calculations and processing
    DOVEFees private immutable _feeManager;
    
    // Max transaction limit flag
    bool private _isMaxTxLimitEnabled = true;
    
    // Dead address for token burning
    address private constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    
    // Admin update proposals (multisig)
    struct AdminUpdateProposal {
        address newAdmin;
        uint256 timestamp;
        uint256 approvalCount;
        mapping(address => bool) hasApproved;
        bool executed;
    }
    
    // Admin update proposal data
    uint256 private _currentProposalId;
    mapping(uint256 => AdminUpdateProposal) private _adminUpdateProposals;
    uint256 private constant PROPOSAL_EXPIRY = 7 days;
    uint256 private constant REQUIRED_APPROVALS = 2;
    
    // Events for admin updates
    event AdminUpdateProposed(uint256 indexed proposalId, address indexed proposer, address indexed newAdmin);
    event AdminUpdateApproved(uint256 indexed proposalId, address indexed approver);
    event AdminUpdateExecuted(uint256 indexed proposalId, address oldAdmin, address newAdmin);
    
    // ================ Constructor ================
    
    /**
     * @dev Constructor initializes the DOVE token
     * @param adminContractAddress Address of the admin contract
     * @param initialCharityWallet Initial charity wallet address 
     */
    constructor(address adminContractAddress, address initialCharityWallet) ERC20("DOVE Token", "DOVE") {
        require(adminContractAddress != address(0), "Admin contract cannot be zero address");
        require(initialCharityWallet != address(0), "Charity wallet cannot be zero address");
        
        // Set admin contract
        _adminContract = IDOVEAdmin(adminContractAddress);
        
        // Create fee manager
        _feeManager = new DOVEFees(address(this), initialCharityWallet);
        
        // Set up initial max tx limit
        _maxTransactionAmount = TOTAL_SUPPLY / 100; // 1% of total supply
        
        // Mint total supply to deployer
        _mint(msg.sender, TOTAL_SUPPLY);
        
        // Pause transfers until launch
        _pause();
    }
    
    // ================ Modifiers ================
    
    /**
     * @dev Only allows the admin contract to call
     */
    modifier onlyAdmin() {
        require(msg.sender == address(_adminContract), "Caller is not the admin contract");
        _;
    }
    
    /**
     * @dev Enforces max transaction limit if enabled
     * @param amount Amount being transferred
     */
    modifier enforceMaxTxLimit(uint256 amount) {
        if (_isMaxTxLimitEnabled && msg.sender != address(_adminContract)) {
            require(amount <= _maxTransactionAmount, "Transfer amount exceeds the maximum allowed");
        }
        _;
    }
    
    // ================ External Functions ================
    
    /**
     * @dev Launch the token, enabling transfers
     * @notice Can only be called by the admin contract
     */
    function launch() external override onlyAdmin {
        require(paused(), "Token is already launched");
        
        // Unpause to enable transfers
        _unpause();
        
        // Record launch in fee manager
        _feeManager.recordLaunch();
        
        emit Launch(block.timestamp);
    }
    
    /**
     * @dev Pause all token transfers
     * @notice Can only be called by the admin contract
     */
    function pause() external override onlyAdmin {
        _pause();
    }
    
    /**
     * @dev Unpause all token transfers
     * @notice Can only be called by the admin contract
     */
    function unpause() external override onlyAdmin {
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
     * @param isDex Whether the address is a DEX
     * @notice Can only be called by the admin contract
     */
    function setDexStatus(address dexAddress, bool isDex) external override onlyAdmin {
        _feeManager.setDexStatus(dexAddress, isDex);
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
    function disableMaxTxLimit() external override onlyAdmin {
        require(_isMaxTxLimitEnabled, "Max transaction limit already disabled");
        _isMaxTxLimitEnabled = false;
        emit MaxTxLimitDisabled();
    }
    
    /**
     * @dev Transfer fee from contract to recipient (only callable by fee manager)
     * @param from Address to deduct from
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return Whether the transfer was successful
     */
    function transferFeeFromContract(address from, address to, uint256 amount) external override returns (bool) {
        require(msg.sender == address(_feeManager), "Only fee manager can call");
        
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
        require(msg.sender == address(_feeManager), "Only fee manager can call");
        
        // Burn by transferring to dead address
        _transfer(from, DEAD_ADDRESS, amount);
        return true;
    }
    
    /**
     * @dev Propose new admin contract address (multisig operation)
     * @param newAdminContract Address of the new admin contract
     * @return proposalId ID of the created proposal
     */
    function proposeAdminUpdate(address newAdminContract) external onlyAdmin returns (uint256 proposalId) {
        require(newAdminContract != address(0), "New admin cannot be zero address");
        require(newAdminContract != address(_adminContract), "New admin same as current");
        
        // Create new proposal ID
        proposalId = _currentProposalId++;
        
        // Initialize proposal
        AdminUpdateProposal storage proposal = _adminUpdateProposals[proposalId];
        proposal.newAdmin = newAdminContract;
        proposal.timestamp = block.timestamp;
        proposal.approvalCount = 1; // Proposer automatically approves
        proposal.hasApproved[msg.sender] = true;
        proposal.executed = false;
        
        emit AdminUpdateProposed(proposalId, msg.sender, newAdminContract);
        emit AdminUpdateApproved(proposalId, msg.sender);
        
        return proposalId;
    }
    
    /**
     * @dev Approve admin update proposal
     * @param proposalId ID of the proposal to approve
     */
    function approveAdminUpdate(uint256 proposalId) external onlyAdmin {
        AdminUpdateProposal storage proposal = _adminUpdateProposals[proposalId];
        
        require(proposal.newAdmin != address(0), "Proposal does not exist");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.hasApproved[msg.sender], "Already approved");
        require(
            block.timestamp <= proposal.timestamp + PROPOSAL_EXPIRY,
            "Proposal expired"
        );
        
        // Record approval
        proposal.hasApproved[msg.sender] = true;
        proposal.approvalCount++;
        
        emit AdminUpdateApproved(proposalId, msg.sender);
        
        // Execute if enough approvals
        if (proposal.approvalCount >= REQUIRED_APPROVALS) {
            _executeAdminUpdate(proposalId);
        }
    }
    
    /**
     * @dev Execute approved admin update
     * @param proposalId ID of the proposal to execute
     */
    function _executeAdminUpdate(uint256 proposalId) private {
        AdminUpdateProposal storage proposal = _adminUpdateProposals[proposalId];
        
        // Mark as executed first to prevent reentrancy
        proposal.executed = true;
        
        // Update admin contract
        address oldAdmin = address(_adminContract);
        _adminContract = IDOVEAdmin(proposal.newAdmin);
        
        emit AdminUpdateExecuted(proposalId, oldAdmin, proposal.newAdmin);
    }
    
    // ================ Event Emission Functions ================
    
    /**
     * @dev Emit charity wallet updated event
     * @param oldWallet Old charity wallet address
     * @param newWallet New charity wallet address
     */
    function emitCharityWalletUpdated(address oldWallet, address newWallet) external override {
        require(msg.sender == address(_feeManager), "Only fee manager can call");
        emit CharityWalletUpdated(oldWallet, newWallet);
    }
    
    /**
     * @dev Emit excluded from fee updated event
     * @param account Address that was updated
     * @param excluded Whether the address is excluded
     */
    function emitExcludedFromFeeUpdated(address account, bool excluded) external override {
        require(msg.sender == address(_feeManager), "Only fee manager can call");
        emit ExcludedFromFeeUpdated(account, excluded);
    }
    
    /**
     * @dev Emit DEX status updated event
     * @param dexAddress Address that was updated
     * @param isDex Whether the address is a DEX
     */
    function emitDexStatusUpdated(address dexAddress, bool isDex) external override {
        require(msg.sender == address(_feeManager), "Only fee manager can call");
        emit DexStatusUpdated(dexAddress, isDex);
    }
    
    /**
     * @dev Emit early sell tax disabled event
     */
    function emitEarlySellTaxDisabled() external override {
        require(msg.sender == address(_feeManager), "Only fee manager can call");
        emit EarlySellTaxDisabled();
    }
    
    // ================ View Functions ================
    
    /**
     * @dev Get charity fee percentage
     * @return The charity fee percentage (in basis points)
     */
    function getCharityFee() external pure override returns (uint16) {
        return CHARITY_FEE_BP;
    }
    
    /**
     * @dev Get charity wallet address
     * @return The charity wallet address
     */
    function getCharityWallet() external view override returns (address) {
        return _feeManager.getCharityWallet();
    }
    
    /**
     * @dev Check if an address is excluded from fees
     * @param account Address to check
     * @return Whether the address is excluded from fees
     */
    function isExcludedFromFee(address account) external view override returns (bool) {
        return _feeManager.isExcludedFromFee(account);
    }
    
    /**
     * @dev Get current admin contract
     * @return Address of the current admin contract
     */
    function getAdminContract() external view returns (address) {
        return address(_adminContract);
    }
    
    /**
     * @dev Get admin update proposal details
     * @param proposalId ID of the proposal
     * @return newAdmin Proposed new admin address
     * @return timestamp When the proposal was created
     * @return approvalCount Number of approvals received
     * @return executed Whether the proposal was executed
     */
    function getAdminUpdateProposal(uint256 proposalId) external view returns (
        address newAdmin,
        uint256 timestamp,
        uint256 approvalCount,
        bool executed
    ) {
        AdminUpdateProposal storage proposal = _adminUpdateProposals[proposalId];
        return (
            proposal.newAdmin,
            proposal.timestamp,
            proposal.approvalCount,
            proposal.executed
        );
    }
    
    // ================ Internal Functions ================
    
    /**
     * @dev Override ERC20 _transfer to apply fees
     * @param sender Token sender
     * @param recipient Token recipient
     * @param amount Transfer amount
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override enforceMaxTxLimit(amount) nonReentrant {
        require(sender != address(0), "Transfer from the zero address");
        require(recipient != address(0), "Transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        
        // Reject transfers when paused
        if (paused()) {
            require(
                sender == address(_adminContract) || recipient == address(_adminContract),
                "Token transfer paused"
            );
        }
        
        // Process fees if not a fee manager operation
        if (msg.sender != address(_feeManager)) {
            uint256 netAmount = _feeManager.processFees(sender, recipient, amount);
            super._transfer(sender, recipient, netAmount);
        } else {
            // Direct transfer for fee manager (already processed)
            super._transfer(sender, recipient, amount);
        }
    }
}
