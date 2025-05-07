// Completely disable max wallet limit in the DOVE token
// This is a more direct approach than excluding each wallet
// Usage: npx hardhat run scripts/admin/disable-wallet-limit-all.js --network base

const { ethers } = require("hardhat");

async function main() {
  // Contract addresses
  const adminAddress = "0x8527DD7b9CF030Ae2D38091FED33D01bC3b13693";
  
  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);
  
  // Get admin contract instance
  const admin = await ethers.getContractAt("DOVEAdmin", adminAddress);
  
  console.log("Attempting to disable max wallet limit globally...");
  
  console.log("\nThis will permanently disable the max wallet limit.");
  console.log("This means there will be no limit on how many tokens a wallet can hold.");
  console.log("This is useful for distributing tokens to allocation wallets.");
  
  console.log("Disabling max wallet limit...");
  try {
    // The disableMaxWalletLimit function in DOVEAdmin completely disables the limit for all wallets
    const tx = await admin.disableMaxWalletLimit({
      gasLimit: 300000
    });
    console.log(`Transaction hash: ${tx.hash}`);
    console.log("Waiting for transaction confirmation...");
    await tx.wait();
    console.log("✅ Max wallet limit disabled successfully!");
    console.log("\nYou can now transfer any amount of tokens to any wallet.");
    console.log("This change is permanent and cannot be reversed.");
  } catch (error) {
    console.error("Error disabling max wallet limit:", error.message);
    
    // If the error is related to a timelock
    if (error.message.includes("Timelock not elapsed")) {
      console.log("\n⚠️ This function requires a timelock period.");
      console.log("You need to schedule this operation and wait for the timelock to elapse before executing it.");
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
