// Initialize DOVE token script for Base Sepolia testnet
// Usage: npx hardhat run scripts/admin/initialize-token.js --network baseSepolia

const { ethers } = require("hardhat");

async function main() {
  // Hardcoded contract addresses from our deployment
  const tokenAddress = "0x272aaD940552f67C3cC763734AdA53f1A4bA3375";
  const feesAddress = "0x383223Adf3ae6EC2BeD1E9Fa4fcfc42434820827";
  const adminAddress = "0xA4732CdB0916B6B4a04d32d20CB72eE53858C745";

  console.log(`Initializing DOVE token (${tokenAddress}) with Fees contract (${feesAddress})`);

  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);

  // Get contract instances
  const dove = await ethers.getContractAt("DOVE", tokenAddress);
  
  // Initialize the token with the fees contract
  console.log("Initializing DOVE token contracts...");
  const tx = await dove.initialiseTokenContracts(feesAddress);
  console.log(`Transaction hash: ${tx.hash}`);
  console.log("Waiting for transaction confirmation...");
  await tx.wait();

  console.log("Initialization successful!");
  console.log("\nYou can now check your token on BaseScan:");
  console.log(`https://sepolia.basescan.org/address/${tokenAddress}`);
  
  // Add instructions to interact with the token
  console.log("\nTo add the DOVE token to MetaMask:");
  console.log("1. Open MetaMask and select 'Import tokens'");
  console.log(`2. Enter token contract address: ${tokenAddress}`);
  console.log("3. Enter token symbol: DOVE");
  console.log("4. Enter decimals: 18");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
