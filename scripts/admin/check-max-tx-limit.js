// Check and adjust max transaction limit settings
// Usage: npx hardhat run scripts/admin/check-max-tx-limit.js --network base

const { ethers } = require("hardhat");

async function main() {
  // Contract addresses
  const tokenAddress = "0x7be8982c3f67B136a695874dF4536E603e8023a6";
  const adminAddress = "0x8527DD7b9CF030Ae2D38091FED33D01bC3b13693";
  
  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);
  
  // Connect to contracts
  const dove = await ethers.getContractAt("DOVE", tokenAddress);
  const admin = await ethers.getContractAt("DOVEAdmin", adminAddress);
  
  // Check if max transaction is enabled
  try {
    const maxTxAmount = await dove.getMaxTransactionAmount();
    console.log(`Current max transaction amount: ${ethers.utils.formatEther(maxTxAmount)} DOVE`);
    
    // Calculate 0.5% of supply
    const totalSupply = await dove.totalSupply();
    const halfPercentOfSupply = totalSupply.mul(5).div(1000); // 0.5%
    console.log(`0.5% of total supply: ${ethers.utils.formatEther(halfPercentOfSupply)} DOVE`);
    
    // Check if there's a function to disable it
    console.log("\nAvailable max transaction control functions in admin contract:");
    
    // Try common function names
    const functionNames = [
      "setMaxTransactionAmount", 
      "disableMaxTransactionLimit", 
      "removeMaxTransactionLimit",
      "setMaxTxPercent"
    ];
    
    for (const funcName of functionNames) {
      try {
        // Check if function exists by trying to get its signature
        const fragment = admin.interface.getFunction(funcName);
        if (fragment) {
          console.log(`- ${funcName}: Available`);
        }
      } catch (e) {
        console.log(`- ${funcName}: Not found`);
      }
    }
    
    // Provide instructions
    console.log("\nTo disable or increase max transaction limit temporarily:");
    console.log("1. Check which function is available in your admin contract");
    console.log("2. Create a script to call that function with appropriate parameters");
    console.log("3. Re-enable protections after initial distributions are complete");
    
    console.log("\nFor now, use multiple smaller transactions (under max limit)");
    
  } catch (error) {
    console.log("Error checking max transaction amount:", error.message);
    console.log("Your contract might not have a max transaction limit, or it has a different implementation");
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
