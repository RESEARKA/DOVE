// Bypass existing timelock and launch DOVE token on Base Sepolia testnet
// Usage: npx hardhat run scripts/admin/bypass-existing-timelock.js --network baseSepolia

const { ethers } = require("hardhat");

async function main() {
  // Contract addresses
  const tokenAddress = "0x272aaD940552f67C3cC763734AdA53f1A4bA3375";
  const adminAddress = "0xA4732CdB0916B6B4a04d32d20CB72eE53858C745";
  
  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);
  
  // Get contract instances
  const dove = await ethers.getContractAt("DOVE", tokenAddress);
  const admin = await ethers.getContractAt("DOVEAdmin", adminAddress);
  
  // Check current state
  console.log("\n=== Current Token State ===");
  console.log(`Token is paused: ${await dove.paused()}`);
  console.log(`Token is fully initialized: ${await dove.isFullyInitialized()}`);
  
  try {
    // Skip Step 1 since the operation is already scheduled
    console.log("\n=== STEP 1: Bypass Timelock ===");
    console.log("Setting the timelock as elapsed...");
    const LAUNCH_OP = ethers.keccak256(ethers.toUtf8Bytes("dove.admin.launch"));
    console.log(`LAUNCH_OP hash: ${LAUNCH_OP}`);
    const bypassTx = await admin.TEST_setOperationTimelockElapsed(LAUNCH_OP);
    await bypassTx.wait();
    console.log("Timelock bypassed successfully!");
    
    console.log("\n=== STEP 2: Execute Launch Operation ===");
    console.log("Calling launch() to execute...");
    const launchTx = await admin.launch();
    await launchTx.wait();
    console.log("Launch execution completed!");
    
    // Check final state
    console.log("\n=== Final Token State ===");
    const isPaused = await dove.paused();
    console.log(`Token is paused: ${isPaused}`);
    
    if (!isPaused) {
      console.log("\n🎉 SUCCESS! Your DOVE token is now unpaused and ready for transfers!");
      console.log(`You can now use your DOVE tokens on Base Sepolia testnet:`);
      console.log(`- Token Address: ${tokenAddress}`);
      console.log(`- Symbol: DOVE`);
      console.log(`- Decimals: 18`);
    } else {
      console.log("\n⚠️ Token is still paused after launch attempt.");
      console.log("This may indicate a deeper issue with the contract implementation.");
    }
    
  } catch (error) {
    console.error("Error during token launch:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
