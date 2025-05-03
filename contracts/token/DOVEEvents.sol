// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title DOVEEvents
 * @dev Event emission contract for DOVE token ecosystem
 * This contract centralizes all event declarations and emission functions
 */
contract DOVEEvents {
    // ================ Events ================
    
    /**
     * @dev Emitted when the token is launched
     * @param timestamp Time of launch
     */
    event Launch(uint256 timestamp);
    
    /**
     * @dev Emitted when the charity wallet is changed
     * @param oldWallet Previous charity wallet address
     * @param newWallet New charity wallet address
     */
    event CharityWalletUpdated(address indexed oldWallet, address indexed newWallet);
    
    /**
     * @dev Emitted when an address is excluded from fees
     * @param account Address that was excluded
     * @param isExcluded Whether the address is excluded
     */
    event ExcludedFromFeeUpdated(address indexed account, bool isExcluded);
    
    /**
     * @dev Emitted when a DEX address status is set
     * @param dexAddress Address that was updated
     * @param dexStatus Whether the address is a DEX
     */
    event DexStatusUpdated(address indexed dexAddress, bool dexStatus);
    
    /**
     * @dev Emitted when the early sell tax is disabled
     */
    event EarlySellTaxDisabled();
    
    /**
     * @dev Emitted when the max transaction limit is disabled
     */
    event MaxTxLimitDisabled();
    
    // ================ Owner/Authorized Addresses ================
    
    // DOVE token address
    address private _doveToken;
    
    // Initialized flag to prevent re-initialization
    bool private _initialized;
    
    // ================ Initialization ================
    
    /**
     * @dev Constructor
     * Empty constructor - initialization happens in initialize function
     */
    constructor() {}
    
    /**
     * @dev Initialize the contract
     * @param doveToken DOVE token address
     * @return True if initialization was successful
     */
    function initialize(address doveToken) external returns (bool) {
        require(!_initialized, "Already initialized");
        require(doveToken != address(0), "DOVE cannot be zero address");
        
        _doveToken = doveToken;
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
    
    // ================ Event Emission Functions ================
    
    /**
     * @dev Emit launch event
     * @param timestamp Time of launch
     */
    function emitLaunch(uint256 timestamp) external onlyDOVE {
        emit Launch(timestamp);
    }
    
    /**
     * @dev Emit charity wallet updated event
     * @param oldWallet Old charity wallet address
     * @param newWallet New charity wallet address
     */
    function emitCharityWalletUpdated(address oldWallet, address newWallet) external onlyDOVE {
        emit CharityWalletUpdated(oldWallet, newWallet);
    }
    
    /**
     * @dev Emit fee exclusion updated event
     * @param account Address that was updated
     * @param excluded Whether the address is excluded
     */
    function emitExcludedFromFeeUpdated(address account, bool excluded) external onlyDOVE {
        emit ExcludedFromFeeUpdated(account, excluded);
    }
    
    /**
     * @dev Emit DEX status updated event
     * @param dexAddress Address that was updated
     * @param dexStatus Whether the address is a DEX
     */
    function emitDexStatusUpdated(address dexAddress, bool dexStatus) external onlyDOVE {
        emit DexStatusUpdated(dexAddress, dexStatus);
    }
    
    /**
     * @dev Emit early sell tax disabled event
     */
    function emitEarlySellTaxDisabled() external onlyDOVE {
        emit EarlySellTaxDisabled();
    }
    
    /**
     * @dev Emit max transaction limit disabled event
     */
    function emitMaxTxLimitDisabled() external onlyDOVE {
        emit MaxTxLimitDisabled();
    }
}
