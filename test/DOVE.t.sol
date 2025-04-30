// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../contracts/DOVE.sol";

/**
 * @title DOVETest
 * @dev Test contract for DOVE token
 */
contract DOVETest is Test {
    // Test accounts
    address private owner;
    address private alice;
    address private bob;
    address private carol;
    address private dex;

    // The DOVE token contract
    DOVE private dove;

    // Initial supply
    uint256 private constant TOTAL_SUPPLY = 100_000_000_000 * 1e18;

    // Events for testing
    event Transfer(address indexed from, address indexed to, uint256 value);
    event CharityFeeCollected(uint256 amount);
    event EarlySellTaxCollected(address indexed seller, uint256 taxAmount);
    event ExcludeFromFee(address indexed account, bool excluded);

    /**
     * @dev Setup test environment before each test
     */
    function setUp() public {
        // Create test accounts
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");
        dex = makeAddr("dex");

        // Deploy DOVE token
        dove = new DOVE();

        // Set up the dex as excluded from fee (simulating a router/LP)
        dove.excludeFromFee(dex);
    }

    /**
     * @dev Test initial supply and owner balance
     */
    function testInitialSupply() public {
        assertEq(dove.totalSupply(), TOTAL_SUPPLY);
        assertEq(dove.balanceOf(owner), TOTAL_SUPPLY);
    }

    /**
     * @dev Test basic transfer functionality
     */
    function testBasicTransfer() public {
        uint256 transferAmount = 1000 * 1e18;
        
        // Transfer from owner to alice
        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, alice, transferAmount);
        dove.transfer(alice, transferAmount);
        
        // Check balances after transfer
        assertEq(dove.balanceOf(alice), transferAmount);
        assertEq(dove.balanceOf(owner), TOTAL_SUPPLY - transferAmount);
    }

    /**
     * @dev Test charity fee mechanism
     */
    function testCharityFee() public {
        // First send some tokens to alice
        uint256 initialAmount = 1000 * 1e18;
        dove.transfer(alice, initialAmount);
        
        // Now alice sends to bob (this will incur charity fee)
        uint256 transferAmount = 100 * 1e18;
        uint256 charityFee = transferAmount * 50 / 10000; // 0.5% fee
        
        vm.startPrank(alice);
        
        vm.expectEmit(true, true, false, false);
        emit CharityFeeCollected(charityFee);
        
        dove.transfer(bob, transferAmount);
        vm.stopPrank();
        
        // Bob should receive amount - fee
        assertEq(dove.balanceOf(bob), transferAmount - charityFee);
        
        // Alice should have initial - transfer
        assertEq(dove.balanceOf(alice), initialAmount - transferAmount);
        
        // Owner should get some charity (very small amount)
        assertGt(dove.balanceOf(owner), TOTAL_SUPPLY - initialAmount);
    }
    
    /**
     * @dev Test early-sell tax functionality
     */
    function testEarlySellTax() public {
        // First give alice some tokens
        uint256 initialAmount = 1000 * 1e18;
        dove.transfer(alice, initialAmount);
        
        // Simulate trading begins (launch timestamp set)
        vm.prank(alice);
        dove.transfer(bob, 1); // This sets the launch timestamp
        
        // Now alice sells to DEX (which will trigger early sell tax)
        uint256 transferAmount = 100 * 1e18;
        
        // Early sell tax should be 3% for first 24 hours
        uint256 expectedEarlySellTax = transferAmount * 300 / 10000; // 3%
        uint256 expectedCharityFee = transferAmount * 50 / 10000; // 0.5%
        uint256 totalFee = expectedEarlySellTax + expectedCharityFee;
        
        vm.startPrank(alice);
        
        vm.expectEmit(true, true, false, false);
        emit EarlySellTaxCollected(alice, expectedEarlySellTax);
        
        dove.transfer(dex, transferAmount);
        vm.stopPrank();
        
        // DEX should receive amount - fee
        assertEq(dove.balanceOf(dex), transferAmount - totalFee);
    }
    
    /**
     * @dev Test excluding account from fee
     */
    function testExcludeFromFee() public {
        // First give alice some tokens
        uint256 initialAmount = 1000 * 1e18;
        dove.transfer(alice, initialAmount);
        
        // Exclude alice from fee
        vm.expectEmit(true, false, false, true);
        emit ExcludeFromFee(alice, true);
        
        dove.excludeFromFee(alice);
        
        // Now alice transfers to bob without fee
        uint256 transferAmount = 100 * 1e18;
        
        vm.startPrank(alice);
        dove.transfer(bob, transferAmount);
        vm.stopPrank();
        
        // Bob should receive full amount (no fee)
        assertEq(dove.balanceOf(bob), transferAmount);
    }
    
    /**
     * @dev Test max transaction limit
     */
    function testMaxTransactionLimit() public {
        // First give alice some tokens
        uint256 initialAmount = 10_000_000 * 1e18;
        dove.transfer(alice, initialAmount);
        
        // Simulate trading begins (launch timestamp set)
        vm.prank(alice);
        dove.transfer(bob, 1); // This sets the launch timestamp
        
        // Get max tx limit
        uint256 maxTxLimit = dove.getMaxTransactionAmount();
        
        // Try to transfer more than limit
        vm.startPrank(alice);
        vm.expectRevert("Transfer amount exceeds max transaction limit");
        dove.transfer(bob, maxTxLimit + 1);
        vm.stopPrank();
        
        // Try with limit amount (should work)
        vm.startPrank(alice);
        dove.transfer(bob, maxTxLimit);
        vm.stopPrank();
        
        assertEq(dove.balanceOf(bob), maxTxLimit + 1); // +1 from previous transfer
    }
    
    /**
     * @dev Test disabling early sell tax
     */
    function testDisableEarlySellTax() public {
        // Simulate trading begins
        vm.prank(alice);
        dove.transfer(bob, 1); // This sets the launch timestamp
        
        // Disable early sell tax
        dove.disableEarlySellTax();
        
        // Verify early sell tax is 0 now
        assertEq(dove.getEarlySellTaxFor(alice), 0);
    }
    
    /**
     * @dev Test disabling max transaction limit
     */
    function testDisableMaxTxLimit() public {
        // Disable max tx limit
        dove.disableMaxTxLimit();
        
        // Verify max tx limit is now max uint256
        assertEq(dove.getMaxTransactionAmount(), type(uint256).max);
    }
    
    /**
     * @dev Test tax rate decreases over time
     */
    function testEarlySellTaxDecreases() public {
        // Simulate trading begins
        vm.prank(alice);
        dove.transfer(bob, 1); // This sets the launch timestamp
        
        // Check initial tax rate (day 1)
        assertEq(dove.getEarlySellTaxFor(alice), 300); // 3%
        
        // Advance time by 1 day
        skip(1 days);
        
        // Check tax rate for day 2
        assertEq(dove.getEarlySellTaxFor(alice), 200); // 2%
        
        // Advance time by 1 more day
        skip(1 days);
        
        // Check tax rate for day 3
        assertEq(dove.getEarlySellTaxFor(alice), 100); // 1%
        
        // Advance time by 1 more day
        skip(1 days);
        
        // Check tax rate after 3 days (should be 0)
        assertEq(dove.getEarlySellTaxFor(alice), 0);
    }
}
