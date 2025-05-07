// Execute DOVE token launch on Base Mainnet (after 24-hour timelock)
// Usage: npx hardhat run scripts/admin/execute-launch.js --network base

const { ethers } = require("hardhat");

async function main() {
  // Contract addresses
  const tokenAddress = "0x7be8982c3f67B136a695874dF4536E603e8023a6";
  const adminAddress = "0x8527DD7b9CF030Ae2D38091FED33D01bC3b13693";
  
  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);
  
  // Get contract instances
  const dove = await ethers.getContractAt("DOVE", tokenAddress);
  const admin = await ethers.getContractAt("DOVEAdmin", adminAddress);
  
  // Check if token is paused
  const isPaused = await dove.paused();
  if (!isPaused) {
    console.log("Token is already active (not paused). No action needed.");
    return;
  }
  
  console.log("Executing token launch (after 24-hour timelock)...");
  try {
    const launchTx = await admin.launch();
    await launchTx.wait();
    console.log("Token launch executed successfully!");
    
    // Verify token is now unpaused
    const finalPaused = await dove.paused();
    console.log(`Token paused status: ${finalPaused}`);
    
    if (!finalPaused) {
      console.log("\n🎉 SUCCESS! Your DOVE token is now live on Base Mainnet!");
      console.log("Users can now transfer tokens freely.");
    } else {
      console.log("\n⚠️ Token is still paused. The timelock may not have elapsed yet.");
      console.log("Please wait the full 24 hours from when you scheduled the launch.");
    }
  } catch (error) {
    console.error("Error executing launch:", error.message);
    
    if (error.message.includes("Timelock not elapsed")) {
      console.log("\nThe 24-hour timelock has not elapsed yet.");
      console.log("Please wait the full 24 hours from when you scheduled the launch.");
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
