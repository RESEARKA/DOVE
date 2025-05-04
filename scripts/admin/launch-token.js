// Launch DOVE token on Base Sepolia testnet
// Usage: npx hardhat run scripts/admin/launch-token.js --network baseSepolia

const { ethers } = require("hardhat");

async function main() {
  // Hardcoded contract addresses from our deployment
  const tokenAddress = "0x272aaD940552f67C3cC763734AdA53f1A4bA3375";
  const adminAddress = "0xA4732CdB0916B6B4a04d32d20CB72eE53858C745";
  
  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);
  
  // Get contract instances
  const dove = await ethers.getContractAt("DOVE", tokenAddress);
  const admin = await ethers.getContractAt("DOVEAdmin", adminAddress);
  
  try {
    // Check if token is already launched
    const isPaused = await dove.paused();
    
    if (!isPaused) {
      console.log("Token is already unpaused and ready for transfers!");
    } else {
      console.log("Attempting to launch (unpause) the token...");
      
      // Try to unpause directly through the token contract
      try {
        console.log("Trying to unpause directly...");
        const unpauseTx = await dove.unpause();
        await unpauseTx.wait();
        console.log("Successfully unpaused the token!");
      } catch (error) {
        console.log("Direct unpause failed, trying via admin contract...");
        
        // Try to launch through the admin contract
        try {
          console.log("Launching through admin contract...");
          const launchTx = await admin.unpause();
          await launchTx.wait();
          console.log("Successfully launched the token via admin contract!");
        } catch (adminError) {
          console.error("Admin launch failed:", adminError.message);
          console.log("\nPlease verify your wallet has the correct permissions.");
        }
      }
    }
    
    // Check final status
    const finalPauseState = await dove.paused();
    console.log(`\nFinal status: Token is ${finalPauseState ? 'still paused' : 'now active for transfers'}`);
    console.log("You can now use your DOVE tokens on Base Sepolia testnet!");
    console.log("Token Address: " + tokenAddress);
    
  } catch (error) {
    console.error("Error launching token:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
