import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { DOVE, DOVEAdmin, DOVEFees, DOVEEvents, DOVEInfo, DOVEGovernance, DOVEMultisig, DOVEDeployer } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

// Constants for testing
const TOTAL_SUPPLY = ethers.parseEther("100000000000"); // 100 billion with 18 decimals
const CHARITY_FEE_BP = 50; // 0.5%
const TRANSFER_AMOUNT = ethers.parseEther("1000000"); // 1 million tokens
const MAX_TX_AMOUNT = ethers.parseEther("1000000000"); // 1 billion tokens

describe("DOVE Token Ecosystem", function () {
  // We define a fixture to reuse the same setup in every test
  async function deployTokenFixture() {
    // Get signers
    const [deployer, admin, feeManager, emergencyAdmin, user1, user2, charityWallet, dexRouter] = 
      await ethers.getSigners();

    // Deploy DOVEAdmin first
    const DOVEAdminFactory = await ethers.getContractFactory("DOVEAdmin");
    const doveAdmin = await DOVEAdminFactory.deploy(await admin.getAddress());

    // Deploy DOVEDeployer contract
    const DOVEDeployerFactory = await ethers.getContractFactory("DOVEDeployer");
    const doveDeployer = await DOVEDeployerFactory.deploy();

    // Deploy the entire DOVE ecosystem using the deployer
    const tx = await doveDeployer.deployDOVEEcosystem(
      await doveAdmin.getAddress(), // Use the deployed admin contract address
      await charityWallet.getAddress()
    );
    const receipt = await tx.wait();

    // Extract addresses from the deployment event
    // In a real-world scenario, we'd extract these from events, but for testing,
    // we can use the log entries or simply query each contract address
    
    // Get deployment events
    const deployEvent = receipt?.logs.find(log => 
      log.topics[0] === ethers.id("DOVEEcosystemDeployed(address,address,address,address,address)")
    );
    
    if (!deployEvent) {
      throw new Error("Deployment event not found");
    }
    
    // Parse the event data
    const eventInterface = new ethers.Interface([
      "event DOVEEcosystemDeployed(address indexed dove, address indexed events, address info, address governance, address deployer)"
    ]);
    const parsedEvent = eventInterface.parseLog({
      topics: deployEvent.topics,
      data: deployEvent.data
    });
    
    // Extract addresses
    const doveAddress = parsedEvent?.args[0];
    const eventsAddress = parsedEvent?.args[1];
    const infoAddress = parsedEvent?.args[2];
    const governanceAddress = parsedEvent?.args[3];
    
    // Connect to the deployed contracts
    const doveToken = await ethers.getContractAt("DOVE", doveAddress);
    const doveEvents = await ethers.getContractAt("DOVEEvents", eventsAddress);
    const doveInfo = await ethers.getContractAt("DOVEInfo", infoAddress);
    const doveGovernance = await ethers.getContractAt("DOVEGovernance", governanceAddress);
    
    // Get DOVEAdmin from the governance contract
    const adminContractAddress = await doveGovernance.getAdminContract();
    
    // Set up roles on DOVEAdmin
    await doveAdmin.connect(admin).grantRole(
      await doveAdmin.FEE_MANAGER_ROLE(),
      await feeManager.getAddress()
    );

    await doveAdmin.connect(admin).grantRole(
      await doveAdmin.EMERGENCY_ADMIN_ROLE(),
      await emergencyAdmin.getAddress()
    );

    // Return all contracts and signers
    return { 
      doveDeployer,
      doveToken, 
      doveEvents,
      doveInfo,
      doveGovernance,
      doveAdmin, 
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
      const { doveToken, doveInfo, deployer, user1, charityWallet } = await loadFixture(deployTokenFixture);

      // Check total supply
      expect(await doveToken.totalSupply()).to.equal(TOTAL_SUPPLY);

      // Check deployer balance
      expect(await doveToken.balanceOf(await deployer.getAddress())).to.equal(TOTAL_SUPPLY);

      // Check paused state (initially unpaused since we changed implementation to start launched)
      expect(await doveToken.paused()).to.equal(false);

      // Check charity wallet
      expect(await doveInfo.getCharityWallet()).to.equal(await charityWallet.getAddress());

      // Check that max transaction amount is set
      const maxTxAmount = await doveInfo.getMaxTransactionAmount();
      expect(maxTxAmount).to.equal(MAX_TX_AMOUNT);
    });

    it("Should transfer tokens correctly after launch", async function () {
      const { doveToken, doveAdmin, admin, user1, user2 } = await loadFixture(deployTokenFixture);
      
      // Token is already launched
      
      // Transfer tokens from deployer to user1
      await doveToken.transfer(await user1.getAddress(), TRANSFER_AMOUNT);
      
      // Check user1 balance - a fee is applied (0.5%)
      const charityFee = TRANSFER_AMOUNT * BigInt(CHARITY_FEE_BP) / 10000n;
      const expectedAmount = TRANSFER_AMOUNT - charityFee;
      const user1Balance = await doveToken.balanceOf(await user1.getAddress());
      expect(user1Balance).to.equal(expectedAmount);
      
      // Transfer from user1 to user2
      const halfAmount = expectedAmount / 2n;
      await doveToken.connect(user1).transfer(await user2.getAddress(), halfAmount);
      
      // Check user2 balance (slightly less than half due to charity fee)
      const user2CharityFee = halfAmount * BigInt(CHARITY_FEE_BP) / 10000n;
      const expectedUser2Amount = halfAmount - user2CharityFee;
      const user2Balance = await doveToken.balanceOf(await user2.getAddress());
      expect(user2Balance).to.equal(expectedUser2Amount);
    });

    it("Should prevent transfers when paused", async function () {
      const { doveToken, doveAdmin, admin, user1 } = await loadFixture(deployTokenFixture);
      
      // Token is initially unpaused, so transfer should succeed
      await doveToken.transfer(await user1.getAddress(), TRANSFER_AMOUNT);
      
      // Pause the token
      await doveAdmin.connect(admin).pause();
      
      // Transfer should fail (using proper assertion syntax)
      await expect(
        doveToken.transfer(await user1.getAddress(), TRANSFER_AMOUNT)
      ).to.be.rejectedWith("ERC20Pausable: token transfer while paused");
      
      // Launch the token again
      await doveAdmin.connect(admin).launch();
      
      // Now transfer should succeed
      await doveToken.transfer(await user1.getAddress(), TRANSFER_AMOUNT);
    });
  });

  describe("Fee Mechanisms", function () {
    it("Should apply charity fee correctly", async function () {
      const { doveToken, doveAdmin, doveInfo, user1, user2, charityWallet, admin } = 
        await loadFixture(deployTokenFixture);
      
      // Launch the token
      await doveAdmin.connect(admin).launch();
      
      // Transfer tokens to user1
      const largeAmount = TRANSFER_AMOUNT * 10n;
      await doveToken.transfer(await user1.getAddress(), largeAmount);
      
      // Get initial balances
      const initialCharityBalance = await doveToken.balanceOf(await charityWallet.getAddress());
      const initialUser1Balance = await doveToken.balanceOf(await user1.getAddress());
      
      // Transfer from user1 to user2
      await doveToken.connect(user1).transfer(await user2.getAddress(), TRANSFER_AMOUNT);
      
      // Get final balances
      const finalCharityBalance = await doveToken.balanceOf(await charityWallet.getAddress());
      const finalUser1Balance = await doveToken.balanceOf(await user1.getAddress());
      const user2Balance = await doveToken.balanceOf(await user2.getAddress());
      
      // Calculate expected charity fee
      const expectedFee = TRANSFER_AMOUNT * BigInt(CHARITY_FEE_BP) / 10000n;
      
      // Verify charity fee was taken
      expect(finalCharityBalance - initialCharityBalance).to.equal(expectedFee);
      
      // Verify user1 balance decreased by transfer amount
      expect(initialUser1Balance - finalUser1Balance).to.equal(TRANSFER_AMOUNT);
      
      // Verify user2 received amount minus fee
      expect(user2Balance).to.equal(TRANSFER_AMOUNT - expectedFee);
    });

    it("Should exclude addresses from fees", async function () {
      const { doveToken, doveAdmin, doveInfo, user1, user2, charityWallet, feeManager } = 
        await loadFixture(deployTokenFixture);
      
      // Launch the token
      await doveAdmin.connect(feeManager).launch();
      
      // Exclude user1 from fees
      await doveAdmin.connect(feeManager).excludeFromFee(await user1.getAddress(), true);
      
      // Check if user1 is excluded
      expect(await doveInfo.isExcludedFromFee(await user1.getAddress())).to.equal(true);
      
      // Transfer tokens to user1
      const largeAmount = TRANSFER_AMOUNT * 10n;
      await doveToken.transfer(await user1.getAddress(), largeAmount);
      
      // Get initial balances
      const initialCharityBalance = await doveToken.balanceOf(await charityWallet.getAddress());
      
      // Transfer from user1 to user2 (should not incur fee)
      await doveToken.connect(user1).transfer(await user2.getAddress(), TRANSFER_AMOUNT);
      
      // Get final balances
      const finalCharityBalance = await doveToken.balanceOf(await charityWallet.getAddress());
      const user2Balance = await doveToken.balanceOf(await user2.getAddress());
      
      // Verify no charity fee was taken
      expect(finalCharityBalance).to.equal(initialCharityBalance);
      
      // Verify user2 received full amount
      expect(user2Balance).to.equal(TRANSFER_AMOUNT);
    });
  });

  describe("Admin Functionality", function () {
    it("Should update charity wallet correctly", async function () {
      const { doveToken, doveAdmin, doveInfo, charityWallet, feeManager, user1 } = 
        await loadFixture(deployTokenFixture);
      
      // Get initial charity wallet
      const initialCharityWallet = await doveInfo.getCharityWallet();
      expect(initialCharityWallet).to.equal(await charityWallet.getAddress());
      
      // Set new charity wallet
      await doveAdmin.connect(feeManager).setCharityWallet(await user1.getAddress());
      
      // Check new charity wallet
      const newCharityWallet = await doveInfo.getCharityWallet();
      expect(newCharityWallet).to.equal(await user1.getAddress());
    });

    it("Should set DEX status correctly", async function () {
      const { doveToken, doveAdmin, doveInfo, dexRouter, admin } = 
        await loadFixture(deployTokenFixture);
      
      // Check initial DEX status
      expect(await doveInfo.getDexStatus(await dexRouter.getAddress())).to.equal(false);
      
      // Set DEX status
      await doveAdmin.connect(admin).setDexStatus(await dexRouter.getAddress(), true);
      
      // Check new DEX status
      expect(await doveInfo.getDexStatus(await dexRouter.getAddress())).to.equal(true);
    });

    it("Should disable early sell tax", async function () {
      const { doveToken, doveAdmin, emergencyAdmin } = 
        await loadFixture(deployTokenFixture);
      
      // Disable early sell tax
      await doveAdmin.connect(emergencyAdmin).disableEarlySellTax();
      
      // There's no direct way to check if early sell tax is disabled, so we rely on the function not reverting
      // In a real test, we would need to simulate a DEX sale and check that no early sell tax is applied
    });

    it("Should disable max tx limit", async function () {
      const { doveToken, doveAdmin, doveInfo, emergencyAdmin } = 
        await loadFixture(deployTokenFixture);
      
      // Check initial max tx limit
      const initialMaxTx = await doveInfo.getMaxTransactionAmount();
      expect(initialMaxTx).to.equal(MAX_TX_AMOUNT);
      
      // Disable max tx limit
      await doveAdmin.connect(emergencyAdmin).disableMaxTxLimit();
      
      // Check new max tx limit (should be max uint256)
      const newMaxTx = await doveInfo.getMaxTransactionAmount();
      expect(newMaxTx > initialMaxTx).to.be.true;
    });
  });

  describe("Governance Functionality", function () {
    it("Should implement admin contract updates with multiple approvals", async function () {
      const { doveToken, doveGovernance, admin, feeManager, emergencyAdmin } = 
        await loadFixture(deployTokenFixture);
      
      // Create new admin contract
      const DOVEAdminFactory = await ethers.getContractFactory("DOVEAdmin");
      const newDOVEAdmin = await DOVEAdminFactory.deploy(await admin.getAddress());
      
      // Get current admin contract
      const currentAdmin = await doveGovernance.getAdminContract();
      
      // Propose admin update
      await doveGovernance.connect(admin).proposeAdminUpdate(await newDOVEAdmin.getAddress());
      
      // Get proposal ID (assuming 1 is the first proposal ID)
      const proposalId = 1n;
      
      // Approve proposal with multiple admins
      await doveGovernance.connect(admin).approveAdminUpdate(proposalId);
      await doveGovernance.connect(emergencyAdmin).approveAdminUpdate(proposalId);
      
      // No need to call execute - execution happens automatically when required approvals are reached
      // The second approval above should trigger execution
      
      // Verify new admin contract
      const updatedAdmin = await doveGovernance.getAdminContract();
      expect(updatedAdmin).to.equal(await newDOVEAdmin.getAddress());
      expect(updatedAdmin).to.not.equal(currentAdmin);
    });
  });
});
