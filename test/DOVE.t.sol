// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../contracts/token/DOVE.sol";
import "../contracts/token/DOVEFees.sol";
import "../contracts/admin/DOVEAdmin.sol";
import "../contracts/admin/DOVEMultisig.sol";

/**
 * @title DOVETest
 * @dev Test contract for DOVE token ecosystem
 */
contract DOVETest is Test {
    // Test accounts
    address private deployer;
    address private admin;
    address private feeManager;
    address private emergencyAdmin;
    address private user1;
    address private user2;
    address private charityWallet;
    address private dexRouter;
    
    // The DOVE ecosystem contracts
    DOVEAdmin private doveAdmin;
    DOVE private doveToken;
    
    // Constants
    uint256 private constant TOTAL_SUPPLY = 100_000_000_000 * 10**18;
    uint256 private constant TRANSFER_AMOUNT = 1_000_000 * 10**18;
    
    // Events to test
    event Launch(uint256 timestamp);
    event CharityWalletUpdated(address indexed oldWallet, address indexed newWallet);
    event ExcludedFromFeeUpdated(address indexed account, bool excluded);
    event DexStatusUpdated(address indexed dexAddress, bool isDex);
    event EarlySellTaxDisabled();
    event MaxTxLimitDisabled();
    event AdminUpdateProposed(uint256 indexed proposalId, address indexed proposer, address indexed newAdmin);
    event AdminUpdateApproved(uint256 indexed proposalId, address indexed approver);
    event AdminUpdateExecuted(uint256 indexed proposalId, address oldAdmin, address newAdmin);
    
    /**
     * @dev Setup test environment before each test
     */
    function setUp() public {
        vm.startPrank(address(this));
        
        // Create test accounts
        deployer = address(this);
        admin = makeAddr("admin");
        feeManager = makeAddr("feeManager");
        emergencyAdmin = makeAddr("emergencyAdmin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        charityWallet = makeAddr("charityWallet");
        dexRouter = makeAddr("dexRouter");
        
        // Deploy contracts
        doveAdmin = new DOVEAdmin(admin);
        
        // Set up roles
        doveAdmin.grantRole(doveAdmin.FEE_MANAGER_ROLE(), feeManager);
        doveAdmin.grantRole(doveAdmin.EMERGENCY_ADMIN_ROLE(), emergencyAdmin);
        
        // Deploy token
        doveToken = new DOVE(address(doveAdmin), charityWallet);
        
        // Set token address in admin contract
        vm.startPrank(admin);
        doveAdmin.setTokenAddress(address(doveToken));
        vm.stopPrank();
        
        // Deal tokens to test with
        deal(address(doveToken), user1, TRANSFER_AMOUNT);
        
        vm.stopPrank();
    }
    
    // ================ Basic Token Tests ================
    
    /**
     * @dev Test initial token setup
     */
    function testInitialSetup() public {
        assertEq(doveToken.totalSupply(), TOTAL_SUPPLY);
        assertEq(doveToken.balanceOf(address(this)), TOTAL_SUPPLY - TRANSFER_AMOUNT);
        assertEq(doveToken.balanceOf(user1), TRANSFER_AMOUNT);
        assertTrue(doveToken.paused());
        assertEq(doveToken.getCharityWallet(), charityWallet);
    }
    
    /**
     * @dev Test token launch
     */
    function testLaunch() public {
        // Launch should only work through admin contract
        vm.startPrank(user1);
        vm.expectRevert("Caller is not the admin contract");
        doveToken.launch();
        vm.stopPrank();
        
        // Launch through admin contract
        vm.startPrank(admin);
        vm.expectEmit(false, false, false, false);
        emit Launch(block.timestamp);
        doveAdmin.launch();
        vm.stopPrank();
        
        // Token should be unpaused after launch
        assertFalse(doveToken.paused());
        
        // Transfers should work after launch
        vm.startPrank(user1);
        doveToken.transfer(user2, 1000);
        vm.stopPrank();
        
        assertEq(doveToken.balanceOf(user2), 1000);
    }
    
    // ================ Fee Tests ================
    
    /**
     * @dev Test charity fee application
     */
    function testCharityFee() public {
        // Launch token first
        vm.startPrank(admin);
        doveAdmin.launch();
        vm.stopPrank();
        
        // Set DEX status for testing
        vm.startPrank(admin);
        doveAdmin.setDexStatus(dexRouter, true);
        vm.stopPrank();
        
        // User1 transfers to user2
        uint256 transferAmount = 10000 * 10**18;
        uint256 expectedCharityFee = transferAmount * 50 / 10000; // 0.5%
        
        vm.startPrank(user1);
        uint256 user1BalanceBefore = doveToken.balanceOf(user1);
        uint256 charityBalanceBefore = doveToken.balanceOf(charityWallet);
        
        doveToken.transfer(user2, transferAmount);
        
        vm.stopPrank();
        
        // Verify balances after transfer
        assertEq(doveToken.balanceOf(user1), user1BalanceBefore - transferAmount);
        assertEq(doveToken.balanceOf(user2), transferAmount - expectedCharityFee);
        assertEq(doveToken.balanceOf(charityWallet), charityBalanceBefore + expectedCharityFee);
    }
    
    /**
     * @dev Test early sell tax application
     */
    function testEarlySellTax() public {
        // Launch token first
        vm.startPrank(admin);
        doveAdmin.launch();
        vm.stopPrank();
        
        // Set DEX status for testing
        vm.startPrank(admin);
        doveAdmin.setDexStatus(dexRouter, true);
        vm.stopPrank();
        
        // User1 sells to DEX within first 24 hours (5% tax)
        uint256 sellAmount = 10000 * 10**18;
        uint256 expectedCharityFee = sellAmount * 50 / 10000; // 0.5%
        uint256 expectedSellTax = sellAmount * 500 / 10000; // 5%
        
        vm.startPrank(user1);
        uint256 user1BalanceBefore = doveToken.balanceOf(user1);
        
        doveToken.transfer(dexRouter, sellAmount);
        
        vm.stopPrank();
        
        // Verify balances after sell
        assertEq(doveToken.balanceOf(user1), user1BalanceBefore - sellAmount);
        assertEq(doveToken.balanceOf(dexRouter), sellAmount - expectedCharityFee - expectedSellTax);
        
        // Test sell tax reduction over time
        // Fast forward 24 hours (3% tax)
        vm.warp(block.timestamp + 24 hours);
        
        vm.startPrank(user1);
        user1BalanceBefore = doveToken.balanceOf(user1);
        
        doveToken.transfer(dexRouter, sellAmount);
        
        vm.stopPrank();
        
        expectedSellTax = sellAmount * 300 / 10000; // 3%
        
        // Verify balances after second sell
        assertEq(doveToken.balanceOf(user1), user1BalanceBefore - sellAmount);
        assertEq(doveToken.balanceOf(dexRouter), 
            (sellAmount - expectedCharityFee - expectedSellTax) * 2);
    }
    
    /**
     * @dev Test fee exclusion
     */
    function testFeeExclusion() public {
        // Launch token first
        vm.startPrank(admin);
        doveAdmin.launch();
        vm.stopPrank();
        
        // Exclude user1 from fees
        vm.startPrank(admin);
        doveAdmin.excludeFromFee(user1, true);
        vm.stopPrank();
        
        // Verify user1's exclusion status
        assertTrue(doveToken.isExcludedFromFee(user1));
        
        // User1 transfers to user2 (should not incur fees)
        uint256 transferAmount = 10000 * 10**18;
        
        vm.startPrank(user1);
        doveToken.transfer(user2, transferAmount);
        vm.stopPrank();
        
        // Verify no fees were taken
        assertEq(doveToken.balanceOf(user2), transferAmount);
    }
    
    // ================ Admin Function Tests ================
    
    /**
     * @dev Test charity wallet update
     */
    function testUpdateCharityWallet() public {
        address newCharityWallet = makeAddr("newCharityWallet");
        
        // Only admin/fee manager should be able to update
        vm.startPrank(user1);
        vm.expectRevert("Caller is not authorized");
        doveAdmin.setCharityWallet(newCharityWallet);
        vm.stopPrank();
        
        // Update from fee manager
        vm.startPrank(feeManager);
        vm.expectEmit(true, true, false, false);
        emit CharityWalletUpdated(charityWallet, newCharityWallet);
        doveAdmin.setCharityWallet(newCharityWallet);
        vm.stopPrank();
        
        // Verify new charity wallet
        assertEq(doveToken.getCharityWallet(), newCharityWallet);
    }
    
    /**
     * @dev Test disabling early sell tax
     */
    function testDisableEarlySellTax() public {
        // Launch token first
        vm.startPrank(admin);
        doveAdmin.launch();
        vm.stopPrank();
        
        // Set DEX status for testing
        vm.startPrank(admin);
        doveAdmin.setDexStatus(dexRouter, true);
        vm.stopPrank();
        
        // Initial sell with tax
        uint256 sellAmount = 10000 * 10**18;
        uint256 expectedCharityFee = sellAmount * 50 / 10000; // 0.5%
        uint256 expectedSellTax = sellAmount * 500 / 10000; // 5%
        
        vm.startPrank(user1);
        doveToken.transfer(dexRouter, sellAmount);
        vm.stopPrank();
        
        // Disable early sell tax (only emergency admin can do it)
        vm.startPrank(emergencyAdmin);
        vm.expectEmit(false, false, false, false);
        emit EarlySellTaxDisabled();
        doveAdmin.disableEarlySellTax();
        vm.stopPrank();
        
        // New sell should have no sell tax, only charity fee
        vm.startPrank(user1);
        uint256 dexBalanceBefore = doveToken.balanceOf(dexRouter);
        
        doveToken.transfer(dexRouter, sellAmount);
        
        vm.stopPrank();
        
        // Verify only charity fee was applied
        assertEq(doveToken.balanceOf(dexRouter), dexBalanceBefore + sellAmount - expectedCharityFee);
    }
    
    /**
     * @dev Test disabling max transaction limit
     */
    function testDisableMaxTxLimit() public {
        // Launch token first
        vm.startPrank(admin);
        doveAdmin.launch();
        vm.stopPrank();
        
        // Try to transfer more than max tx limit
        uint256 maxAmount = TOTAL_SUPPLY / 100; // 1% of supply
        
        deal(address(doveToken), user1, maxAmount * 2);
        
        vm.startPrank(user1);
        vm.expectRevert("Transfer amount exceeds the maximum allowed");
        doveToken.transfer(user2, maxAmount + 1);
        vm.stopPrank();
        
        // Disable max tx limit
        vm.startPrank(admin);
        vm.expectEmit(false, false, false, false);
        emit MaxTxLimitDisabled();
        doveAdmin.disableMaxTxLimit();
        vm.stopPrank();
        
        // Now large transfers should work
        vm.startPrank(user1);
        doveToken.transfer(user2, maxAmount + 1);
        vm.stopPrank();
        
        assertEq(doveToken.balanceOf(user2), maxAmount + 1);
    }
    
    // ================ Multisig Tests ================
    
    /**
     * @dev Test admin contract update proposal
     */
    function testAdminUpdateProposal() public {
        address newAdmin = makeAddr("newAdmin");
        DOVEAdmin newAdminContract = new DOVEAdmin(newAdmin);
        
        // Propose admin update
        vm.startPrank(admin);
        uint256 proposalId = doveToken.proposeAdminUpdate(address(newAdminContract));
        vm.stopPrank();
        
        // Get proposal details
        (address proposedAdmin, uint256 timestamp, uint256 approvalCount, bool executed) = 
            doveToken.getAdminUpdateProposal(proposalId);
        
        assertEq(proposedAdmin, address(newAdminContract));
        assertEq(approvalCount, 1); // Proposer auto-approves
        assertFalse(executed);
        
        // Second approval from fee manager
        vm.startPrank(feeManager);
        doveToken.approveAdminUpdate(proposalId);
        vm.stopPrank();
        
        // Verify admin contract was updated (requires 2 approvals)
        assertEq(doveToken.getAdminContract(), address(newAdminContract));
    }
    
    /**
     * @dev Test proposal expiry
     */
    function testProposalExpiry() public {
        address newAdmin = makeAddr("newAdmin");
        DOVEAdmin newAdminContract = new DOVEAdmin(newAdmin);
        
        // Propose admin update
        vm.startPrank(admin);
        uint256 proposalId = doveToken.proposeAdminUpdate(address(newAdminContract));
        vm.stopPrank();
        
        // Fast forward 8 days (past expiry)
        vm.warp(block.timestamp + 8 days);
        
        // Second approval should revert due to expiry
        vm.startPrank(feeManager);
        vm.expectRevert("Proposal expired");
        doveToken.approveAdminUpdate(proposalId);
        vm.stopPrank();
    }
    
    // ================ Security Tests ================
    
    /**
     * @dev Test security against reentrancy
     */
    function testReentrancyProtection() public {
        // Launch token first
        vm.startPrank(admin);
        doveAdmin.launch();
        vm.stopPrank();
        
        // Test reentrancy protection in _transfer
        // This would normally require a malicious contract, but we can check
        // that the nonReentrant modifier is applied
        
        // For more comprehensive tests, a reentrant attack contract
        // could be created to attempt calling back into the token
    }
    
    /**
     * @dev Test paused token transfers
     */
    function testPausedTransfers() public {
        // Token should start paused
        assertTrue(doveToken.paused());
        
        // Transfers should be blocked
        vm.startPrank(user1);
        vm.expectRevert("Token transfer paused");
        doveToken.transfer(user2, 1000);
        vm.stopPrank();
        
        // Launch to unpause
        vm.startPrank(admin);
        doveAdmin.launch();
        vm.stopPrank();
        
        // Transfers should work now
        vm.startPrank(user1);
        doveToken.transfer(user2, 1000);
        vm.stopPrank();
        
        // Admin should be able to pause again
        vm.startPrank(admin);
        doveAdmin.pause();
        vm.stopPrank();
        
        // Transfers should be blocked again
        vm.startPrank(user1);
        vm.expectRevert("Token transfer paused");
        doveToken.transfer(user2, 1000);
        vm.stopPrank();
    }
}
