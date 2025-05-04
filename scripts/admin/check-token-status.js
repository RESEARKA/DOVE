// Check DOVE token status on Base Sepolia testnet
// Usage: npx hardhat run scripts/admin/check-token-status.js --network baseSepolia

const { ethers } = require("hardhat");

async function main() {
  // Hardcoded contract addresses from our deployment
  const tokenAddress = "0x272aaD940552f67C3cC763734AdA53f1A4bA3375";
  const feesAddress = "0x383223Adf3ae6EC2BeD1E9Fa4fcfc42434820827";
  const adminAddress = "0xA4732CdB0916B6B4a04d32d20CB72eE53858C745";
  
  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);
  
  // Get contract instances
  const dove = await ethers.getContractAt("DOVE", tokenAddress);
  
  try {
    // Check basic token information
    const name = await dove.name();
    const symbol = await dove.symbol();
    const totalSupply = await dove.totalSupply();
    const formattedSupply = ethers.formatEther(totalSupply);
    
    console.log("\n=== DOVE Token Information ===");
    console.log(`Name: ${name}`);
    console.log(`Symbol: ${symbol}`);
    console.log(`Total Supply: ${formattedSupply} DOVE`);
    
    // Check deployer's balance
    const deployerBalance = await dove.balanceOf(deployer.address);
    const formattedBalance = ethers.formatEther(deployerBalance);
    console.log(`Your Balance: ${formattedBalance} DOVE`);
    
    // Check if paused
    const isPaused = await dove.paused();
    console.log(`Token is ${isPaused ? 'paused' : 'not paused'}`);
    
    // Check if admin has roles
    const adminRole = await dove.hasRole(ethers.keccak256(ethers.toUtf8Bytes("DEFAULT_ADMIN_ROLE")), deployer.address);
    console.log(`Deployer has admin role: ${adminRole}`);
    
    console.log("\nThe token appears to be deployed correctly.");
    console.log("You can now add it to your MetaMask wallet:");
    console.log(`Token Address: ${tokenAddress}`);
    console.log("Token Symbol: DOVE");
    console.log("Decimals: 18");
    
  } catch (error) {
    console.error("Error checking token status:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
