// Diagnose DOVE token issues on Base Sepolia testnet
// Usage: npx hardhat run scripts/admin/diagnose-token.js --network baseSepolia

const { ethers } = require("hardhat");

async function main() {
  // Contract addresses
  const tokenAddress = "0x272aaD940552f67C3cC763734AdA53f1A4bA3375";
  const adminAddress = "0xA4732CdB0916B6B4a04d32d20CB72eE53858C745";
  const feesAddress = "0x383223Adf3ae6EC2BeD1E9Fa4fcfc42434820827";
  const eventsAddress = "0x626403C79A93d683021262B8828851ED49A14ab2";
  const governanceAddress = "0xB1FfB484601C7179e532ED5fFDAdF9A5Dd8ad210";
  const infoAddress = "0x0002643D3778c3F0aee670a32C10DC1E9B5E031f";
  
  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);
  
  // Get contract instances
  const dove = await ethers.getContractAt("DOVE", tokenAddress);
  const admin = await ethers.getContractAt("DOVEAdmin", adminAddress);
  const fees = await ethers.getContractAt("DOVEFees", feesAddress);
  const events = await ethers.getContractAt("DOVEEvents", eventsAddress);
  const governance = await ethers.getContractAt("DOVEGovernance", governanceAddress);
  const info = await ethers.getContractAt("DOVEInfo", infoAddress);

  console.log("\n=== 1. Token Status ===");
  console.log(`Token is paused: ${await dove.paused()}`);
  console.log(`Token is fully initialized: ${await dove.isFullyInitialized()}`);
  
  console.log("\n=== 2. Token Addresses ===");
  try {
    console.log(`DOVE token has admin contract: ${await dove.getAdminContractAddress()}`);
    console.log(`DOVE token has fee manager: ${await dove.getFeeManager()}`);
  } catch (error) {
    console.log("Error getting token addresses:", error.message);
  }
  
  console.log("\n=== 3. Admin Contract Status ===");
  try {
    // Check if the operations timelock was properly bypassed
    const LAUNCH_OP = ethers.keccak256(ethers.toUtf8Bytes("dove.admin.launch"));
    console.log(`LAUNCH_OP hash: ${LAUNCH_OP}`);
    
    // Check if TESTING flag is true in DOVEAdmin
    const TESTING_ROLE = ethers.keccak256(ethers.toUtf8Bytes("TESTING_ROLE"));
    console.log(`TESTING flag role check: ${await admin.hasRole(TESTING_ROLE, deployer.address)}`);
    
    // Check roles
    const DEFAULT_ADMIN_ROLE = await admin.DEFAULT_ADMIN_ROLE();
    console.log(`Deployer has DEFAULT_ADMIN_ROLE: ${await admin.hasRole(DEFAULT_ADMIN_ROLE, deployer.address)}`);
    
    // Check if admin contract knows the token
    console.log(`Admin has token address: ${await admin.getDOVEAddress()}`);

    console.log("\nTrying to explicitly call unpause...");
    try {
      // Try to call unpause directly on the token
      const tx = await dove.unpause();
      await tx.wait();
      console.log("Successfully unpaused the token!");
    } catch (error) {
      console.log("Direct unpause failed:", error.message);
    }
  } catch (error) {
    console.log("Error diagnosing admin contract:", error.message);
  }
  
  console.log("\n=== 4. Final Status Check ===");
  console.log(`Token is now paused: ${await dove.paused()}`);
  
  // Provide recommendations
  console.log("\n=== 5. Recommendations ===");
  console.log("1. If the token is still paused, try deploying a new set of contracts with TESTING = true");
  console.log("2. Make sure your wallet has the DEFAULT_ADMIN_ROLE and can call the appropriate functions");
  console.log("3. Remember that contracts built with initialization patterns require proper sequencing");
  console.log("4. Consider using BaseScan to interact with the contracts directly");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
