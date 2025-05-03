import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { DOVE, DOVEAdmin, DOVEFeeController } from "../typechain-types";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { BaseContract, ContractTransactionResponse } from "ethers";

describe("DOVE Token and Controllers", function () {
  let owner: SignerWithAddress;
  let charity: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let dex: SignerWithAddress;
  let dove: DOVE;
  let doveAdmin: DOVEAdmin;
  let doveFeeController: DOVEFeeController;
  const totalSupply = ethers.parseEther("100000000000"); // 100 billion

  // --- Deploy Fixture --- //
  async function deployContracts() {
    const [owner, charity, user1, user2, dex] = await ethers.getSigners();

    // Deploy DOVEFeeController first (needed by DOVEAdmin)
    const DoveFeeController = await ethers.getContractFactory("contracts/fees/DOVEFeeController.sol:DOVEFeeController");
    const doveFeeController = await DoveFeeController.deploy(await charity.getAddress()) as DOVEFeeController;
    await doveFeeController.waitForDeployment();
    const doveFeeControllerAddress = await doveFeeController.getAddress();

    // Deploy DOVEAdmin (needs FeeController address)
    const DoveAdmin = await ethers.getContractFactory("contracts/admin/DOVEAdmin.sol:DOVEAdmin");
    // Corrected: Pass FeeController address, add type casting
    const doveAdmin = await DoveAdmin.deploy(doveFeeControllerAddress) as DOVEAdmin;
    await doveAdmin.waitForDeployment();
    const doveAdminAddress = await doveAdmin.getAddress();

    // Deploy DOVE Token (needs Admin and FeeController addresses)
    const Dove = await ethers.getContractFactory("contracts/token/DOVE.sol:DOVE");
    // Corrected: Pass addresses using getAddress()
    const dove = await Dove.deploy(doveAdminAddress, doveFeeControllerAddress) as DOVE;
    await dove.waitForDeployment();
    const doveAddress = await dove.getAddress();

    // --- Post-Deployment Setup --- //

    // Set Token Address on managers
    // Corrected: Use getAddress()
    await doveFeeController.setTokenAddress(doveAddress);

    // Grant TOKEN_ROLE on Fee Controller to the DOVE token contract
    const tokenRole = await doveFeeController.TOKEN_ROLE();
    // Corrected: Use getAddress()
    await doveFeeController.grantRole(tokenRole, doveAddress);

    // Fetch roles AFTER controllers are deployed
    const FEE_MANAGER_ROLE = await doveFeeController.FEE_MANAGER_ROLE();
    const EMERGENCY_ADMIN_ROLE = await doveFeeController.EMERGENCY_ADMIN_ROLE();

    // Grant necessary roles to the deployer (owner) for testing
    await doveAdmin.grantRole(FEE_MANAGER_ROLE, await owner.getAddress());
    await doveFeeController.grantRole(FEE_MANAGER_ROLE, await owner.getAddress());
    await doveFeeController.grantRole(EMERGENCY_ADMIN_ROLE, await owner.getAddress());

    // Set the Admin address on the Fee Controller (if needed by design - check contract)
    // await doveFeeController.setAdminAddress(doveAdminAddress);

    return { dove, doveAdmin, doveFeeController, owner, charity, user1, user2, dex };
  }

  // --- Tests --- //

  // Load fixture before each test for clean state
  beforeEach(async function() {
    const deployed = await loadFixture(deployContracts);
    dove = deployed.dove;
    doveAdmin = deployed.doveAdmin;
    doveFeeController = deployed.doveFeeController;
    owner = deployed.owner;
    charity = deployed.charity;
    user1 = deployed.user1;
    user2 = deployed.user2;
    dex = deployed.dex;
  });

  describe("Basic token functionality", function () {
    it("Should set the correct token metadata", async function () {
      expect(await dove.name()).to.equal("DOVE");
      expect(await dove.symbol()).to.equal("DOVE");
      expect(await dove.decimals()).to.equal(18);
    });

    it("Should mint the total supply to the deployer", async function () {
      // Corrected: Use getAddress()
      expect(await dove.balanceOf(await owner.getAddress())).to.equal(totalSupply);
      expect(await dove.totalSupply()).to.equal(totalSupply);
    });

    it("Should allow basic transfers", async function () {
      const transferAmount = ethers.parseEther("1000");
      // Corrected: Use getAddress()
      await dove.transfer(await user1.getAddress(), transferAmount);
      // Corrected: Use getAddress()
      expect(await dove.balanceOf(await user1.getAddress())).to.equal(transferAmount);
    });
  });

  describe("Charity fee functionality", function () {
    it("Should return the correct charity fee", async function () {
      expect(await dove.getCharityFee()).to.equal(50); // 0.5% = 50 basis points
    });

    it("Should transfer tokens with charity fee", async function () {
      // First transfer tokens to user
      const initialAmount = ethers.parseEther("10000");
      // Corrected: Use getAddress()
      await dove.transfer(await user1.getAddress(), initialAmount);

      // Setup DEX for testing
      // Corrected: Use getAddress()
      await doveAdmin.setDexStatus(await dex.getAddress(), true);

      // Now transfer from user to another user (with fee)
      const transferAmount = ethers.parseEther("1000");
      const fee = transferAmount * 50n / 10000n; // 0.5%
      const expectedReceived = transferAmount - fee;

      // Track balances before and after
      // Corrected: Use getAddress()
      const charityBefore = await dove.balanceOf(await charity.getAddress());

      // Make the transfer
      // Corrected: Use getAddress()
      await dove.connect(user1).transfer(await user2.getAddress(), transferAmount);

      // Check balances
      // Corrected: Use getAddress()
      expect(await dove.balanceOf(await user2.getAddress())).to.equal(expectedReceived);
      // Corrected: Use getAddress()
      expect(await dove.balanceOf(await charity.getAddress())).to.equal(charityBefore + fee);
      // Corrected: Use getAddress()
      expect(await dove.balanceOf(await user1.getAddress())).to.equal(initialAmount - transferAmount);
    });

    it("Should exclude addresses from fees when marked", async function () {
      // First transfer tokens to users
      const initialAmount = ethers.parseEther("10000");
      // Corrected: Use getAddress()
      await dove.transfer(await user1.getAddress(), initialAmount);

      // Exclude user1 from fees
      // Corrected: Use getAddress()
      await doveAdmin.connect(owner).excludeFromFee(await user1.getAddress(), true);
      // Corrected: Use getAddress()
      expect(await doveFeeController.isExcludedFromFee(await user1.getAddress())).to.be.true;

      // Now transfer without fee
      const transferAmount = ethers.parseEther("1000");

      // Track balances before and after
      // Corrected: Use getAddress()
      const charityBefore = await dove.balanceOf(await charity.getAddress());

      // Make the transfer
      // Corrected: Use getAddress()
      await dove.connect(user1).transfer(await user2.getAddress(), transferAmount);

      // Check balances - no fee should be taken
      // Corrected: Use getAddress()
      expect(await dove.balanceOf(await user2.getAddress())).to.equal(transferAmount);
      // Corrected: Use getAddress()
      expect(await dove.balanceOf(await charity.getAddress())).to.equal(charityBefore); // No change
    });

    it("Should allow charity wallet to be updated", async function () {
      // Create a new charity wallet
      const newCharity = user2;

      // Update the charity wallet
      // Corrected: Use getAddress()
      await doveFeeController.connect(owner).setCharityWallet(await newCharity.getAddress());

      // Verify the update
      // Corrected: Use getAddress()
      expect(await dove.getCharityWallet()).to.equal(await newCharity.getAddress());

      // Test that fees now go to the new wallet
      const initialAmount = ethers.parseEther("10000");
      // Corrected: Use getAddress()
      await dove.transfer(await user1.getAddress(), initialAmount);

      const transferAmount = ethers.parseEther("1000");
      const fee = transferAmount * 50n / 10000n; // 0.5%

      // Make the transfer
      // Corrected: Use getAddress()
      await dove.connect(user1).transfer(await dex.getAddress(), transferAmount);

      // Verify new charity wallet received the fee
      // Corrected: Use getAddress()
      expect(await dove.balanceOf(await newCharity.getAddress())).to.equal(fee);
    });
  });

  describe("Early sell tax functionality", function () {
    beforeEach(async function () {
      // Launch the token to enable early sell tax
      await doveAdmin.connect(owner).launch();

      // Mark DEX as known
      // Corrected: Use getAddress()
      await doveAdmin.setDexStatus(await dex.getAddress(), true);

      // Transfer tokens to user for testing
      const initialAmount = ethers.parseEther("10000");
      // Corrected: Use getAddress()
      await dove.transfer(await user1.getAddress(), initialAmount);
    });

    it("Should apply early sell tax for transfers to DEX", async function () {
      // Check the current early sell tax for our user
      // Corrected: Use getAddress()
      const earlySellTax = await dove.getEarlySellTaxFor(await user1.getAddress());
      expect(earlySellTax).to.be.greaterThan(0); // Assuming default is enabled

      // Transfer to DEX (simulating a sell)
      const transferAmount = ethers.parseEther("1000");
      const charityFee = transferAmount * 50n / 10000n; // 0.5%
      const sellTaxFee = transferAmount * earlySellTax / 10000n;
      const totalFee = charityFee + sellTaxFee;
      const expectedReceived = transferAmount - totalFee;

      // Track balances
      const totalSupplyBefore = await dove.totalSupply();
      // Corrected: Use getAddress()
      const charityBefore = await dove.balanceOf(await charity.getAddress());

      // Make the transfer
      // Corrected: Use getAddress()
      await dove.connect(user1).transfer(await dex.getAddress(), transferAmount);

      // Check balances
      // Corrected: Use getAddress()
      expect(await dove.balanceOf(await dex.getAddress())).to.equal(expectedReceived);
      // Corrected: Use getAddress()
      expect(await dove.balanceOf(await charity.getAddress())).to.equal(charityBefore + charityFee);

      // Verify burn - total supply should decrease by the sell tax amount
      expect(await dove.totalSupply()).to.equal(totalSupplyBefore - sellTaxFee);
    });

    it("Should not apply early sell tax for normal transfers", async function () {
      // Transfer between users (not to DEX)
      const transferAmount = ethers.parseEther("1000");
      const charityFee = transferAmount * 50n / 10000n; // 0.5%
      const expectedReceived = transferAmount - charityFee;

      // Make the transfer
      // Corrected: Use getAddress()
      await dove.connect(user1).transfer(await user2.getAddress(), transferAmount);

      // Check balances - only charity fee should be deducted
      // Corrected: Use getAddress()
      expect(await dove.balanceOf(await user2.getAddress())).to.equal(expectedReceived);
    });

    it("Should allow disabling early sell tax", async function () {
      // Disable early sell tax
      await doveFeeController.connect(owner).disableEarlySellTax();

      // Verify it's disabled
      // Corrected: Use getAddress()
      expect(await dove.getEarlySellTaxFor(await user1.getAddress())).to.equal(0);

      // Transfer to DEX
      const transferAmount = ethers.parseEther("1000");
      const charityFee = transferAmount * 50n / 10000n; // Only 0.5% charity fee should apply
      const expectedReceived = transferAmount - charityFee;

      // Make the transfer
      // Corrected: Use getAddress()
      await dove.connect(user1).transfer(await dex.getAddress(), transferAmount);

      // Check balances - only charity fee should be deducted
      // Corrected: Use getAddress()
      expect(await dove.balanceOf(await dex.getAddress())).to.equal(expectedReceived);
    });

    // Corrected: Assertion syntax revertedWith -> rejectedWith
    it("Should prevent non-owner from disabling early sell tax", async function () {
      await expect(doveFeeController.connect(user1).disableEarlySellTax()).to.be.rejectedWith(
        "AccessControl: account " // Check exact error message
      );
    });
  });

  describe("Max transaction limit", function () {
    it("Should enforce max transaction limit", async function () {
      // Launch the token
      await doveAdmin.connect(owner).launch();

      // Get the max transaction amount
      const maxTxAmount = await dove.getMaxTransactionAmount();

      // Try to transfer slightly more than the max
      const transferAmount = maxTxAmount + 1n;

      // Should revert
      // Corrected: Use getAddress(), Assertion syntax revertedWith -> rejectedWith
      await expect(
        dove.connect(owner).transfer(await user1.getAddress(), transferAmount)
      ).to.be.rejectedWith("DOVE: Max transaction amount exceeded");
    });

    it("Should allow disabling max transaction limit", async function () {
      // Launch the token
      await doveAdmin.connect(owner).launch();

      // Disable max transaction limit
      await doveAdmin.connect(owner).disableMaxTxLimit();

      // Get the initial max transaction amount
      const initialMax = await dove.getMaxTransactionAmount();

      // Should be max uint256 now
      expect(initialMax).to.equal(ethers.MaxUint256);

      // Try to transfer a large amount (that would exceed the previous max)
      const transferAmount = ethers.parseEther("5000000000"); // 5 billion tokens

      // Should succeed
      // Corrected: Use getAddress()
      await dove.transfer(await user1.getAddress(), transferAmount);
      // Corrected: Use getAddress()
      expect(await dove.balanceOf(await user1.getAddress())).to.equal(transferAmount - (transferAmount * 50n / 10000n));
    });
  });

  describe("Launch Functionality", function () {
    it("Should prevent transfers before launch", async function () {
      const transferAmount = ethers.parseEther("1000");
      // Corrected: Use getAddress(), Assertion syntax revertedWith -> rejectedWith
      await expect(dove.transfer(await user1.getAddress(), transferAmount)).to.be.rejectedWith("DOVE: Token not launched yet");
    });

    it("Should allow owner to launch the token", async function () {
      // Corrected: Check if emit check needs await (it does)
      await expect(doveAdmin.connect(owner).launch())
        .to.emit(doveFeeController, "TokenLaunched");
    });

    it("Should prevent non-owner from launching", async function () {
      // Corrected: Assertion syntax revertedWith -> rejectedWith
      await expect(doveAdmin.connect(user1).launch()).to.be.rejectedWith(
        // Use specific role error if Ownable is not used
        "AccessControl: account " // Check exact error message
      );
    });

    it("Should prevent launching twice", async function () {
      await doveAdmin.connect(owner).launch();
      // Corrected: Assertion syntax revertedWith -> rejectedWith
      await expect(doveAdmin.connect(owner).launch()).to.be.rejectedWith(
        "DOVEAdmin: Token already launched"
      );
    });

    it("Should enable transfers after launch", async function () {
      await doveAdmin.connect(owner).launch();
      await doveAdmin.connect(owner).disableMaxTxLimit(); // Disable limit for simple transfer test
      // Corrected: Use ethers.parseUnits
      const amount = ethers.parseUnits("100", 18);
      // Corrected: Use getAddress(), Assertion syntax not.reverted -> not.rejected
      await expect(dove.connect(owner).transfer(await user1.getAddress(), amount)).to.not.be.rejected;
    });
  });
});
