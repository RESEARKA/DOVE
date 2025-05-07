// Simple DOVE token diagnostic script
const { ethers } = require("hardhat");

async function main() {
  // Contract addresses
  const tokenAddress = "0x7be8982c3f67B136a695874dF4536E603e8023a6";
  const adminAddress = "0x8527DD7b9CF030Ae2D38091FED33D01bC3b13693";
  
  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);
  
  // Basic ERC20 ABI
  const erc20ABI = [
    "function name() view returns (string)",
    "function symbol() view returns (string)",
    "function decimals() view returns (uint8)",
    "function totalSupply() view returns (uint256)",
    "function balanceOf(address) view returns (uint256)",
    "function transfer(address to, uint amount) returns (bool)"
  ];
  
  // Admin ABI
  const adminABI = [
    "function isTokenFunctionalityReady() view returns (bool)",
    "function launch() returns (bool)"
  ];
  
  try {
    // Connect to token
    console.log("Connecting to token contract...");
    const dove = new ethers.Contract(tokenAddress, erc20ABI, deployer);
    
    // Connect to admin
    console.log("Connecting to admin contract...");
    const admin = new ethers.Contract(adminAddress, adminABI, deployer);
    
    // Basic token info
    console.log("\n=== Basic Token Info ===");
    try {
      const name = await dove.name();
      console.log(`Name: ${name}`);
    } catch (e) {
      console.log("Could not get name:", e.message);
    }
    
    try {
      const symbol = await dove.symbol();
      console.log(`Symbol: ${symbol}`);
    } catch (e) {
      console.log("Could not get symbol:", e.message);
    }
    
    try {
      const decimals = await dove.decimals();
      console.log(`Decimals: ${decimals}`);
    } catch (e) {
      console.log("Could not get decimals:", e.message);
    }
    
    try {
      const totalSupply = await dove.totalSupply();
      console.log(`Total Supply (raw): ${totalSupply.toString()}`);
    } catch (e) {
      console.log("Could not get total supply:", e.message);
    }
    
    // Check owner balance
    try {
      const balance = await dove.balanceOf(deployer.address);
      console.log(`Your Balance (raw): ${balance.toString()}`);
    } catch (e) {
      console.log("Could not get balance:", e.message);
    }
    
    // Try to execute launch again (in case it didn't work before)
    console.log("\n=== Attempting Launch Again ===");
    try {
      const isReady = await admin.isTokenFunctionalityReady();
      console.log(`Token functionality ready: ${isReady}`);
      
      console.log("Executing launch function...");
      const tx = await admin.launch();
      console.log(`Launch transaction hash: ${tx.hash}`);
      await tx.wait();
      console.log("Launch executed successfully!");
    } catch (e) {
      console.log("Launch failed or already completed:", e.message);
    }
    
    // Try a test transfer
    console.log("\n=== Transfer Test ===");
    try {
      // Create a random address for testing
      const testWallet = ethers.Wallet.createRandom();
      const testAddress = testWallet.address;
      console.log(`Test address: ${testAddress}`);
      
      // Try to transfer 1000 tokens (adjust decimals manually)
      const amount = "1000000000000000000000"; // 1000 tokens with 18 decimals
      console.log(`Attempting to transfer ${amount} (raw value) to test address...`);
      
      const tx = await dove.transfer(testAddress, amount);
      console.log(`Transfer transaction hash: ${tx.hash}`);
      await tx.wait();
      console.log("Transfer successful!");
      
      // Check new balance
      const newBalance = await dove.balanceOf(deployer.address);
      console.log(`New balance (raw): ${newBalance.toString()}`);
    } catch (e) {
      console.log("Transfer failed:", e.message);
    }
    
  } catch (error) {
    console.error(`Script error: ${error.message}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
