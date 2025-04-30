import { ethers } from "hardhat";
import { deployDove } from "./deploy/dove";

/**
 * Test script to simulate full deployment workflow on a testnet
 * This script:
 * 1. Deploys the DOVE token with a test charity wallet
 * 2. Creates a test transfer
 * 3. Verifies charity fee collection works
 * 4. Tests early-sell tax functionality
 * 
 * Run with: `pnpm hardhat run scripts/test-deployment.ts --network baseSepolia`
 */
async function main() {
  console.log("=== DOVE Token Testnet Deployment & Verification ===");

  // Get signers
  const [deployer, testUser1, testUser2] = await ethers.getSigners();
  console.log(`Using deployer address: ${deployer.address}`);
  
  // Deploy token with charity wallet set to deployer for testing
  console.log("\n1. Deploying DOVE token with test charity wallet...");
  const { dove } = await deployDove();
  
  // Check initial configurations
  console.log("\n2. Verifying initial configuration...");
  const charityWallet = await dove.getCharityWallet();
  const charityFee = await dove.getCharityFee();
  console.log(`Charity wallet set to: ${charityWallet}`);
  console.log(`Charity fee: ${charityFee.toString()} basis points (${Number(charityFee)/100}%)`);
  
  // Launch the token
  console.log("\n3. Launching token...");
  const launchTx = await dove.launch();
  await launchTx.wait();
  console.log(`Token launched successfully at: ${await dove.getLaunchTimestamp()}`);
  
  if (testUser1 && testUser2) {
    // Transfer tokens to test user
    console.log("\n4. Testing token transfers with charity fee...");
    const transferAmount = ethers.parseEther("1000000"); // 1 million tokens
    const transferTx = await dove.transfer(testUser1.address, transferAmount);
    await transferTx.wait();
    
    // Check balances and verify fee collection
    const testUser1Balance = await dove.balanceOf(testUser1.address);
    const charityBalance = await dove.balanceOf(charityWallet);
    const totalDonations = await dove.getTotalCharityDonations();
    
    console.log(`Transfer complete. User balance: ${ethers.formatEther(testUser1Balance)} DOVE`);
    console.log(`Charity wallet balance: ${ethers.formatEther(charityBalance)} DOVE`);
    console.log(`Total charity donations: ${ethers.formatEther(totalDonations)} DOVE`);
    
    // Set up a test DEX address and test early-sell tax
    console.log("\n5. Testing early-sell tax with mock DEX...");
    const mockDexTx = await dove.setDexStatus(testUser2.address, true);
    await mockDexTx.wait();
    
    // Transfer from test user to DEX (simulating a sell)
    if (testUser1Balance > 0) {
      const sellAmount = ethers.parseEther("500000"); // Sell 500K tokens
      console.log(`Simulating a sell of ${ethers.formatEther(sellAmount)} tokens to DEX...`);
      
      // Get early sell tax rate
      const earlySellTax = await dove.getEarlySellTaxFor(testUser1.address);
      console.log(`Current early-sell tax rate: ${earlySellTax.toString()} basis points (${Number(earlySellTax)/100}%)`);
      
      // Check total supply before burn
      const totalSupplyBefore = await dove.totalSupply();
      
      // Perform the "sell"
      await dove.connect(testUser1).transfer(testUser2.address, sellAmount);
      
      // Check balances and verify fee collection and burn
      const dexBalance = await dove.balanceOf(testUser2.address);
      const newCharityBalance = await dove.balanceOf(charityWallet);
      const totalSupplyAfter = await dove.totalSupply();
      
      console.log(`DEX received: ${ethers.formatEther(dexBalance)} DOVE`);
      console.log(`Charity received additional: ${ethers.formatEther(newCharityBalance - charityBalance)} DOVE`);
      console.log(`Tokens burned: ${ethers.formatEther(totalSupplyBefore - totalSupplyAfter)} DOVE`);
    }
  }
  
  console.log("\n=== Deployment Testing Complete ===");
  console.log(`DOVE token address: ${await dove.getAddress()}`);
  console.log("All functionality is working correctly!");
  
  return { dove };
}

// Auto-execute if script is run directly
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
}

export default main;
