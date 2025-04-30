import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { DOVE } from "../typechain-types";

describe("DOVE Token", function () {
  let dove: DOVE;
  let owner: SignerWithAddress;
  let charity: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let dex: SignerWithAddress;
  const totalSupply = ethers.parseEther("100000000000"); // 100 billion
  
  // Set up fresh contract before each test
  beforeEach(async function () {
    [owner, charity, user1, user2, dex] = await ethers.getSigners();
    
    // Deploy DOVE with charity wallet
    const Dove = await ethers.getContractFactory("DOVE");
    dove = await Dove.deploy(charity.address) as DOVE;
  });
  
  describe("Basic token functionality", function () {
    it("Should set the correct token metadata", async function () {
      expect(await dove.name()).to.equal("DOVE");
      expect(await dove.symbol()).to.equal("DOVE");
      expect(await dove.decimals()).to.equal(18);
    });
    
    it("Should mint the total supply to the deployer", async function () {
      expect(await dove.balanceOf(owner.address)).to.equal(totalSupply);
      expect(await dove.totalSupply()).to.equal(totalSupply);
    });
    
    it("Should allow basic transfers", async function () {
      const transferAmount = ethers.parseEther("1000");
      await dove.transfer(user1.address, transferAmount);
      expect(await dove.balanceOf(user1.address)).to.equal(transferAmount);
    });
  });
  
  describe("Charity fee functionality", function () {
    it("Should return the correct charity fee", async function () {
      expect(await dove.getCharityFee()).to.equal(50); // 0.5%
    });
    
    it("Should transfer tokens with charity fee", async function () {
      // First transfer tokens to user
      const initialAmount = ethers.parseEther("10000");
      await dove.transfer(user1.address, initialAmount);
      
      // Setup DEX for testing
      await dove.setDexStatus(dex.address, true);
      
      // Now transfer from user to another user (with fee)
      const transferAmount = ethers.parseEther("1000");
      const fee = transferAmount * 50n / 10000n; // 0.5%
      const expectedReceived = transferAmount - fee;
      
      // Track balances before and after
      const charityBefore = await dove.balanceOf(charity.address);
      
      // Make the transfer
      await dove.connect(user1).transfer(user2.address, transferAmount);
      
      // Check balances
      expect(await dove.balanceOf(user2.address)).to.equal(expectedReceived);
      expect(await dove.balanceOf(charity.address)).to.equal(charityBefore + fee);
      expect(await dove.getTotalCharityDonations()).to.equal(fee);
    });
    
    it("Should exclude addresses from fees when marked", async function () {
      // First transfer tokens to users
      const initialAmount = ethers.parseEther("10000");
      await dove.transfer(user1.address, initialAmount);
      
      // Exclude user1 from fees
      await dove.excludeFromFee(user1.address);
      expect(await dove.isExcludedFromFee(user1.address)).to.be.true;
      
      // Now transfer without fee
      const transferAmount = ethers.parseEther("1000");
      
      // Track balances before and after
      const charityBefore = await dove.balanceOf(charity.address);
      
      // Make the transfer
      await dove.connect(user1).transfer(user2.address, transferAmount);
      
      // Check balances - no fee should be taken
      expect(await dove.balanceOf(user2.address)).to.equal(transferAmount);
      expect(await dove.balanceOf(charity.address)).to.equal(charityBefore); // No change
      expect(await dove.getTotalCharityDonations()).to.equal(0);
    });
    
    it("Should allow charity wallet to be updated", async function() {
      // Create a new charity wallet
      const newCharity = user2;
      
      // Update the charity wallet
      await dove.setCharityWallet(newCharity.address);
      
      // Verify the update
      expect(await dove.getCharityWallet()).to.equal(newCharity.address);
      
      // Test that fees now go to the new wallet
      const initialAmount = ethers.parseEther("10000");
      await dove.transfer(user1.address, initialAmount);
      
      const transferAmount = ethers.parseEther("1000");
      const fee = transferAmount * 50n / 10000n; // 0.5%
      
      // Make the transfer
      await dove.connect(user1).transfer(dex.address, transferAmount);
      
      // Verify new charity wallet received the fee
      expect(await dove.balanceOf(newCharity.address)).to.equal(fee);
    });
  });
  
  describe("Early sell tax functionality", function () {
    beforeEach(async function () {
      // Launch the token to enable early sell tax
      await dove.launch();
      
      // Mark DEX as known
      await dove.setDexStatus(dex.address, true);
      
      // Transfer tokens to user for testing
      const initialAmount = ethers.parseEther("10000");
      await dove.transfer(user1.address, initialAmount);
    });
    
    it("Should apply early sell tax for transfers to DEX", async function () {
      // Check the current early sell tax for our user
      const earlySellTax = await dove.getEarlySellTaxFor(user1.address);
      expect(earlySellTax).to.equal(300); // 3% for first 24h
      
      // Transfer to DEX (simulating a sell)
      const transferAmount = ethers.parseEther("1000");
      const charityFee = transferAmount * 50n / 10000n; // 0.5%
      const sellTaxFee = transferAmount * 300n / 10000n; // 3%
      const totalFee = charityFee + sellTaxFee;
      const expectedReceived = transferAmount - totalFee;
      
      // Track balances
      const totalSupplyBefore = await dove.totalSupply();
      const charityBefore = await dove.balanceOf(charity.address);
      
      // Make the transfer
      await dove.connect(user1).transfer(dex.address, transferAmount);
      
      // Check balances
      expect(await dove.balanceOf(dex.address)).to.equal(expectedReceived);
      expect(await dove.balanceOf(charity.address)).to.equal(charityBefore + charityFee);
      
      // Verify burn - total supply should decrease by the sell tax amount
      expect(await dove.totalSupply()).to.equal(totalSupplyBefore - sellTaxFee);
    });
    
    it("Should not apply early sell tax for normal transfers", async function () {
      // Transfer between users (not to DEX)
      const transferAmount = ethers.parseEther("1000");
      const charityFee = transferAmount * 50n / 10000n; // 0.5%
      const expectedReceived = transferAmount - charityFee;
      
      // Make the transfer
      await dove.connect(user1).transfer(user2.address, transferAmount);
      
      // Check balances - only charity fee should be deducted
      expect(await dove.balanceOf(user2.address)).to.equal(expectedReceived);
    });
    
    it("Should allow disabling early sell tax", async function () {
      // Disable early sell tax
      await dove.disableEarlySellTax();
      
      // Verify it's disabled
      expect(await dove.getEarlySellTaxFor(user1.address)).to.equal(0);
      
      // Transfer to DEX
      const transferAmount = ethers.parseEther("1000");
      const charityFee = transferAmount * 50n / 10000n; // Only 0.5% charity fee should apply
      const expectedReceived = transferAmount - charityFee;
      
      // Make the transfer
      await dove.connect(user1).transfer(dex.address, transferAmount);
      
      // Check balances - only charity fee should be deducted
      expect(await dove.balanceOf(dex.address)).to.equal(expectedReceived);
    });
  });
  
  describe("Max transaction limit", function () {
    it("Should enforce max transaction limit", async function () {
      // Launch the token
      await dove.launch();
      
      // Get the max transaction amount
      const maxTxAmount = await dove.getMaxTransactionAmount();
      
      // Try to transfer slightly more than the max
      const transferAmount = maxTxAmount + 1n;
      
      // Should revert
      await expect(
        dove.connect(owner).transfer(user1.address, transferAmount)
      ).to.be.revertedWith("Transfer amount exceeds max transaction limit");
    });
    
    it("Should allow disabling max transaction limit", async function () {
      // Launch the token
      await dove.launch();
      
      // Disable max transaction limit
      await dove.disableMaxTxLimit();
      
      // Get the initial max transaction amount
      const initialMax = await dove.getMaxTransactionAmount();
      
      // Should be max uint256 now
      expect(initialMax).to.equal(ethers.MaxUint256);
      
      // Try to transfer a large amount (that would exceed the previous max)
      const transferAmount = ethers.parseEther("5000000000"); // 5 billion tokens
      
      // Should succeed
      await dove.transfer(user1.address, transferAmount);
      expect(await dove.balanceOf(user1.address)).to.equal(transferAmount - (transferAmount * 50n / 10000n));
    });
  });
});
