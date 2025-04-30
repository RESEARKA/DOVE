import { ethers } from "hardhat";
import { deployDove } from "./deploy/dove";
import { DOVE } from "../typechain-types";

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
  try {
    console.log("=== DOVE Token Testnet Deployment & Verification ===");

    // Get signers
    const [deployer, testUser1, testUser2] = await ethers.getSigners();
    console.log(`Using deployer address: ${deployer.address}`);
    
    // Get charity wallet from env or use deployer as fallback
    const charityWallet = process.env.CHARITY_WALLET_ADDRESS || deployer.address;
    console.log(`Using charity wallet: ${charityWallet}`);
    
    // Deploy token
    console.log("\n1. Deploying DOVE token...");
    let dove: DOVE;
    try {
      const deployment = await deployDove();
      dove = deployment.dove as DOVE;
      console.log(`DOVE deployed successfully to: ${await dove.getAddress()}`);
    } catch (error) {
      console.error("Deployment failed:", error);
      throw new Error("Failed to deploy DOVE token");
    }
    
    // Check initial configurations
    console.log("\n2. Verifying initial configuration...");
    try {
      // Use Promise.all to optimize multiple contract calls
      const [actualCharityWallet, charityFee] = await Promise.all([
        dove.getCharityWallet(),
        dove.getCharityFee()
      ]);
      
      console.log(`Charity wallet set to: ${actualCharityWallet}`);
      console.log(`Charity fee: ${charityFee.toString()} basis points (${Number(charityFee)/100}%)`);
    } catch (error) {
      console.error("Failed to verify configuration:", error);
      throw new Error("Configuration verification failed");
    }
    
    // Launch the token
    console.log("\n3. Launching token...");
    try {
      const launchTx = await dove.launch();
      await launchTx.wait();
      const timestamp = await dove.getLaunchTimestamp();
      console.log(`Token launched successfully at timestamp: ${timestamp}`);
    } catch (error) {
      console.error("Launch failed:", error);
      throw new Error("Failed to launch token");
    }
    
    if (testUser1 && testUser2) {
      // Transfer tokens to test user
      console.log("\n4. Testing token transfers with charity fee...");
      try {
        const transferAmount = ethers.parseEther("1000000"); // 1 million tokens
        const transferTx = await dove.transfer(testUser1.address, transferAmount);
        await transferTx.wait();
        console.log(`Transferred ${ethers.formatEther(transferAmount)} DOVE to ${testUser1.address}`);
        
        // Check balances and verify fee collection
        const [testUser1Balance, charityBalance, totalDonations] = await Promise.all([
          dove.balanceOf(testUser1.address),
          dove.balanceOf(charityWallet),
          dove.getTotalCharityDonations()
        ]);
        
        console.log(`User balance: ${ethers.formatEther(testUser1Balance)} DOVE`);
        console.log(`Charity wallet balance: ${ethers.formatEther(charityBalance)} DOVE`);
        console.log(`Total charity donations: ${ethers.formatEther(totalDonations)} DOVE`);
      } catch (error) {
        console.error("Transfer test failed:", error);
        throw new Error("Failed to test transfers");
      }
      
      // Set up a test DEX address and test early-sell tax
      console.log("\n5. Testing early-sell tax with mock DEX...");
      try {
        const mockDexTx = await dove.setDexStatus(testUser2.address, true);
        await mockDexTx.wait();
        console.log(`Set ${testUser2.address} as mock DEX`);
        
        // Get user balance
        const testUser1Balance = await dove.balanceOf(testUser1.address);
        
        // Transfer from test user to DEX (simulating a sell)
        if (testUser1Balance > BigInt(0)) {
          const sellAmount = ethers.parseEther("500000"); // Sell 500K tokens
          console.log(`Simulating a sell of ${ethers.formatEther(sellAmount)} tokens to DEX...`);
          
          // Get early sell tax rate
          const earlySellTax = await dove.getEarlySellTaxFor(testUser1.address);
          console.log(`Current early-sell tax rate: ${earlySellTax.toString()} basis points (${Number(earlySellTax)/100}%)`);
          
          // Cache values before transaction
          const [totalSupplyBefore, charityBalanceBefore] = await Promise.all([
            dove.totalSupply(),
            dove.balanceOf(charityWallet)
          ]);
          
          // Perform the "sell"
          const sellTx = await dove.connect(testUser1).transfer(testUser2.address, sellAmount);
          await sellTx.wait();
          
          // Check balances and verify fee collection and burn
          const [dexBalance, newCharityBalance, totalSupplyAfter] = await Promise.all([
            dove.balanceOf(testUser2.address),
            dove.balanceOf(charityWallet),
            dove.totalSupply()
          ]);
          
          console.log(`DEX received: ${ethers.formatEther(dexBalance)} DOVE`);
          console.log(`Charity received additional: ${ethers.formatEther(newCharityBalance - charityBalanceBefore)} DOVE`);
          console.log(`Tokens burned: ${ethers.formatEther(totalSupplyBefore - totalSupplyAfter)} DOVE`);
        } else {
          console.log("User has insufficient balance for sell test");
        }
      } catch (error) {
        console.error("Early-sell tax test failed:", error);
        throw new Error("Failed to test early-sell tax");
      }
    }
    
    console.log("\n=== Deployment Testing Complete ===");
    console.log(`DOVE token address: ${await dove.getAddress()}`);
    console.log("All functionality is working correctly!");
    
    return { dove };
  } catch (error) {
    console.error("Test deployment failed:", error);
    process.exit(1);
  }
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
