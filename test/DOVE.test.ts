import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { DOVE, DOVEAdmin, DOVEFees, DOVEMultisig } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

// Constants for testing
const TOTAL_SUPPLY = ethers.parseEther("100000000000"); // 100 billion with 18 decimals
const CHARITY_FEE_BP = 50; // 0.5%
const TRANSFER_AMOUNT = ethers.parseEther("1000000"); // 1 million tokens

describe("DOVE Token Ecosystem", function () {
  // We define a fixture to reuse the same setup in every test
  async function deployTokenFixture() {
    // Get signers
    const [deployer, admin, feeManager, emergencyAdmin, user1, user2, charityWallet, dexRouter] = 
      await ethers.getSigners();

    // Deploy DOVEAdmin contract
    const DOVEAdminFactory = await ethers.getContractFactory("DOVEAdmin");
    const doveAdmin = await DOVEAdminFactory.deploy(await admin.getAddress());

    // Set up roles on DOVEAdmin
    await doveAdmin.connect(admin).grantRole(
      await doveAdmin.FEE_MANAGER_ROLE(),
      await feeManager.getAddress()
    );

    await doveAdmin.connect(admin).grantRole(
      await doveAdmin.EMERGENCY_ADMIN_ROLE(),
      await emergencyAdmin.getAddress()
    );

    // Deploy DOVE token
    const DOVEFactory = await ethers.getContractFactory("DOVE");
    const doveToken = await DOVEFactory.deploy(
      await doveAdmin.getAddress(),
      await charityWallet.getAddress()
    );

    // Set token address in admin contract
    await doveAdmin.connect(admin).setTokenAddress(await doveToken.getAddress());

    // Return all contracts and signers
    return { 
      doveAdmin, 
      doveToken, 
      deployer, 
      admin, 
      feeManager, 
      emergencyAdmin, 
      user1, 
      user2, 
      charityWallet, 
      dexRouter 
    };
  }

  // Basic token tests
  describe("Basic Token Functionality", function () {
    it("Should set the correct initial state", async function () {
      const { doveToken, deployer, user1, charityWallet } = await loadFixture(deployTokenFixture);
      
      // Check total supply
      expect(await doveToken.totalSupply()).to.equal(TOTAL_SUPPLY);
      
      // Check token is initially paused
      expect(await doveToken.paused()).to.be.true;
      
      // Check charity wallet is set correctly
      expect(await doveToken.getCharityWallet()).to.equal(await charityWallet.getAddress());
      
      // Check charity fee percentage
      expect(await doveToken.getCharityFee()).to.equal(CHARITY_FEE_BP);
    });

    it("Should launch token correctly", async function () {
      const { doveToken, doveAdmin, user1, user2, admin } = await loadFixture(deployTokenFixture);
      
      // User1 shouldn't be able to launch directly
      await expect(doveToken.connect(user1).launch())
        .to.be.rejectedWith("Caller is not the admin contract");
      
      // Admin should be able to launch via admin contract
      await doveAdmin.connect(admin).launch();
      
      // Token should be unpaused after launch
      expect(await doveToken.paused()).to.be.false;
      
      // Transfer the user some tokens for testing
      await doveToken.connect(deployer).transfer(await user1.getAddress(), TRANSFER_AMOUNT);
      
      // Transfers should work now
      await doveToken.connect(user1).transfer(await user2.getAddress(), ethers.parseEther("1000"));
      expect(await doveToken.balanceOf(await user2.getAddress())).to.equal(ethers.parseEther("1000"));
    });
  });

  // Fee mechanism tests
  describe("Fee Mechanisms", function () {
    it("Should apply charity fee correctly", async function () {
      const { doveToken, doveAdmin, user1, user2, charityWallet, admin } = 
        await loadFixture(deployTokenFixture);
      
      // Launch token
      await doveAdmin.connect(admin).launch();
      
      // Transfer tokens to user1
      await doveToken.connect(deployer).transfer(await user1.getAddress(), TRANSFER_AMOUNT);
      
      // Calculate expected charity fee
      const transferAmount = ethers.parseEther("10000");
      const expectedFee = (transferAmount * BigInt(CHARITY_FEE_BP)) / BigInt(10000);
      
      // Get initial balances
      const user1BalanceBefore = await doveToken.balanceOf(await user1.getAddress());
      const user2BalanceBefore = await doveToken.balanceOf(await user2.getAddress());
      const charityBalanceBefore = await doveToken.balanceOf(await charityWallet.getAddress());
      
      // Make transfer
      await doveToken.connect(user1).transfer(await user2.getAddress(), transferAmount);
      
      // Check final balances
      expect(await doveToken.balanceOf(await user1.getAddress()))
        .to.equal(user1BalanceBefore - transferAmount);
      
      expect(await doveToken.balanceOf(await user2.getAddress()))
        .to.equal(user2BalanceBefore + transferAmount - expectedFee);
      
      expect(await doveToken.balanceOf(await charityWallet.getAddress()))
        .to.equal(charityBalanceBefore + expectedFee);
    });

    it("Should apply early sell tax correctly", async function () {
      const { doveToken, doveAdmin, dexRouter, user1, admin } = 
        await loadFixture(deployTokenFixture);
      
      // Launch token
      await doveAdmin.connect(admin).launch();
      
      // Set DEX status
      await doveAdmin.connect(admin).setDexStatus(await dexRouter.getAddress(), true);
      
      // Transfer tokens to user1
      await doveToken.connect(deployer).transfer(await user1.getAddress(), TRANSFER_AMOUNT);
      
      // Calculate expected fees for first 24 hours (5% sell tax + 0.5% charity)
      const sellAmount = ethers.parseEther("10000");
      const expectedCharityFee = (sellAmount * BigInt(CHARITY_FEE_BP)) / BigInt(10000);
      const expectedSellTax = (sellAmount * BigInt(500)) / BigInt(10000); // 5%
      
      // Get initial balances
      const user1BalanceBefore = await doveToken.balanceOf(await user1.getAddress());
      const dexBalanceBefore = await doveToken.balanceOf(await dexRouter.getAddress());
      
      // Sell to DEX
      await doveToken.connect(user1).transfer(await dexRouter.getAddress(), sellAmount);
      
      // Check final balances
      expect(await doveToken.balanceOf(await user1.getAddress()))
        .to.equal(user1BalanceBefore - sellAmount);
      
      expect(await doveToken.balanceOf(await dexRouter.getAddress()))
        .to.equal(dexBalanceBefore + sellAmount - expectedCharityFee - expectedSellTax);
    });

    it("Should exclude addresses from fees when configured", async function () {
      const { doveToken, doveAdmin, user1, user2, admin } = 
        await loadFixture(deployTokenFixture);
      
      // Launch token
      await doveAdmin.connect(admin).launch();
      
      // Transfer tokens to user1
      await doveToken.connect(deployer).transfer(await user1.getAddress(), TRANSFER_AMOUNT);
      
      // Exclude user1 from fees
      await doveAdmin.connect(admin).excludeFromFee(await user1.getAddress(), true);
      
      // Verify exclusion status
      expect(await doveToken.isExcludedFromFee(await user1.getAddress())).to.be.true;
      
      // Transfer amount
      const transferAmount = ethers.parseEther("10000");
      
      // Make transfer - should have no fee
      await doveToken.connect(user1).transfer(await user2.getAddress(), transferAmount);
      
      // Recipient should get full amount
      expect(await doveToken.balanceOf(await user2.getAddress()))
        .to.equal(transferAmount);
    });
  });

  // Admin functionality tests
  describe("Admin Functionality", function () {
    it("Should update charity wallet correctly", async function () {
      const { doveToken, doveAdmin, charityWallet, feeManager, user1 } = 
        await loadFixture(deployTokenFixture);
      
      const newCharityWallet = await user1.getAddress();
      
      // Regular user cannot update charity wallet
      await expect(doveAdmin.connect(user1).setCharityWallet(newCharityWallet))
        .to.be.rejectedWith("Caller is not authorized");
      
      // Fee manager should be able to update charity wallet
      await doveAdmin.connect(feeManager).setCharityWallet(newCharityWallet);
      
      // Check charity wallet was updated
      expect(await doveToken.getCharityWallet()).to.equal(newCharityWallet);
    });

    it("Should disable early sell tax correctly", async function () {
      const { doveToken, doveAdmin, dexRouter, user1, admin, emergencyAdmin } = 
        await loadFixture(deployTokenFixture);
      
      // Launch token
      await doveAdmin.connect(admin).launch();
      
      // Set DEX status
      await doveAdmin.connect(admin).setDexStatus(await dexRouter.getAddress(), true);
      
      // Transfer tokens to user1
      await doveToken.connect(deployer).transfer(await user1.getAddress(), TRANSFER_AMOUNT);
      
      // First sell with tax
      const sellAmount = ethers.parseEther("10000");
      await doveToken.connect(user1).transfer(await dexRouter.getAddress(), sellAmount);
      
      // Disable early sell tax
      await doveAdmin.connect(emergencyAdmin).disableEarlySellTax();
      
      // Get initial balances for second sell
      const user1BalanceBefore = await doveToken.balanceOf(await user1.getAddress());
      const dexBalanceBefore = await doveToken.balanceOf(await dexRouter.getAddress());
      
      // Calculate expected charity fee (no sell tax)
      const expectedCharityFee = (sellAmount * BigInt(CHARITY_FEE_BP)) / BigInt(10000);
      
      // Second sell after disabling
      await doveToken.connect(user1).transfer(await dexRouter.getAddress(), sellAmount);
      
      // Check only charity fee was applied
      expect(await doveToken.balanceOf(await dexRouter.getAddress()))
        .to.equal(dexBalanceBefore + sellAmount - expectedCharityFee);
    });

    it("Should disable max transaction limit correctly", async function () {
      const { doveToken, doveAdmin, user1, user2, admin } = 
        await loadFixture(deployTokenFixture);
      
      // Launch token
      await doveAdmin.connect(admin).launch();
      
      // Max tx limit should be 1% of total supply
      const maxTxLimit = TOTAL_SUPPLY / BigInt(100);
      
      // Transfer large amount to user1 for testing
      await doveToken.connect(deployer).transfer(await user1.getAddress(), maxTxLimit * BigInt(2));
      
      // Try to transfer more than max tx limit (should fail)
      await expect(doveToken.connect(user1).transfer(
        await user2.getAddress(), 
        maxTxLimit + BigInt(1)
      )).to.be.rejectedWith("Transfer amount exceeds the maximum allowed");
      
      // Disable max tx limit
      await doveAdmin.connect(admin).disableMaxTxLimit();
      
      // Now large transfers should work
      await doveToken.connect(user1).transfer(await user2.getAddress(), maxTxLimit + BigInt(1));
      expect(await doveToken.balanceOf(await user2.getAddress()))
        .to.equal(maxTxLimit + BigInt(1));
    });
  });

  // Multisig functionality tests
  describe("Multisig Admin Updates", function () {
    it("Should implement admin contract updates with multiple approvals", async function () {
      const { doveToken, doveAdmin, admin, feeManager, user1 } = 
        await loadFixture(deployTokenFixture);
      
      // Deploy a new admin contract
      const DOVEAdminFactory = await ethers.getContractFactory("DOVEAdmin");
      const newAdminContract = await DOVEAdminFactory.deploy(await user1.getAddress());
      
      // Propose an admin update
      await doveToken.connect(admin).proposeAdminUpdate(await newAdminContract.getAddress());
      
      // Get the proposal ID (should be 0 for first proposal)
      const proposalId = 0;
      
      // Get proposal details
      const proposal = await doveToken.getAdminUpdateProposal(proposalId);
      expect(proposal[0]).to.equal(await newAdminContract.getAddress()); // proposedAdmin
      expect(proposal[2]).to.equal(1); // approvalCount (proposer auto-approves)
      expect(proposal[3]).to.equal(false); // executed
      
      // Second approval from fee manager
      await doveToken.connect(feeManager).approveAdminUpdate(proposalId);
      
      // Verify admin contract was updated
      expect(await doveToken.getAdminContract()).to.equal(await newAdminContract.getAddress());
    });

    it("Should not allow expired proposals to be approved", async function () {
      const { doveToken, admin, feeManager } = await loadFixture(deployTokenFixture);
      
      // Deploy a new admin contract
      const DOVEAdminFactory = await ethers.getContractFactory("DOVEAdmin");
      const newAdminContract = await DOVEAdminFactory.deploy(await admin.getAddress());
      
      // Propose an admin update
      await doveToken.connect(admin).proposeAdminUpdate(await newAdminContract.getAddress());
      
      // Get the proposal ID
      const proposalId = 0;
      
      // Fast forward time by 8 days (past the 7 day expiry)
      await ethers.provider.send("evm_increaseTime", [8 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine", []);
      
      // Approval should fail due to expiry
      await expect(doveToken.connect(feeManager).approveAdminUpdate(proposalId))
        .to.be.rejectedWith("Proposal expired");
    });
  });

  // Security tests
  describe("Security Features", function () {
    it("Should prevent transfers when paused", async function () {
      const { doveToken, doveAdmin, user1, user2, admin } = 
        await loadFixture(deployTokenFixture);
      
      // Transfer tokens to user1
      await doveToken.connect(deployer).transfer(await user1.getAddress(), TRANSFER_AMOUNT);
      
      // Token should be paused initially
      expect(await doveToken.paused()).to.be.true;
      
      // Transfers should be blocked
      await expect(doveToken.connect(user1).transfer(
        await user2.getAddress(), 
        ethers.parseEther("1000")
      )).to.be.rejectedWith("Token transfer paused");
      
      // Launch to unpause
      await doveAdmin.connect(admin).launch();
      expect(await doveToken.paused()).to.be.false;
      
      // Transfers should work now
      await doveToken.connect(user1).transfer(
        await user2.getAddress(), 
        ethers.parseEther("1000")
      );
      
      // Admin should be able to pause again
      await doveAdmin.connect(admin).pause();
      expect(await doveToken.paused()).to.be.true;
      
      // Transfers should be blocked again
      await expect(doveToken.connect(user1).transfer(
        await user2.getAddress(), 
        ethers.parseEther("1000")
      )).to.be.rejectedWith("Token transfer paused");
    });
  });
});
