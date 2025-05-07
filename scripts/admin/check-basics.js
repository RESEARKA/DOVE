// Basic DOVE token diagnostic script
// Checks fundamental functions without assumptions about implementation
const { ethers } = require("hardhat");

async function main() {
  // Contract addresses
  const tokenAddress = "0x7be8982c3f67B136a695874dF4536E603e8023a6";
  const adminAddress = "0x8527DD7b9CF030Ae2D38091FED33D01bC3b13693";
  const feesAddress = "0x03E2cF2C11D5Cd468C30De7F2bf3F173CbeBeed7";
  
  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);
  
  // Get basic ERC20 interface (no custom functions)
  const erc20ABI = [
    "function name() view returns (string)",
    "function symbol() view returns (string)",
    "function decimals() view returns (uint8)",
    "function totalSupply() view returns (uint256)",
    "function balanceOf(address) view returns (uint256)",
    "function transfer(address to, uint amount) returns (bool)",
    "function allowance(address owner, address spender) view returns (uint256)",
    "function approve(address spender, uint amount) returns (bool)",
    "function transferFrom(address sender, address recipient, uint amount) returns (bool)"
  ];
  
  const dove = new ethers.Contract(tokenAddress, erc20ABI, deployer);
  
  try {
    console.log("\n=== Basic Token Info ===");
    const name = await dove.name();
    const symbol = await dove.symbol();
    const decimals = await dove.decimals();
    const totalSupply = await dove.totalSupply();
    const formattedSupply = ethers.utils.formatUnits(totalSupply, decimals);
    
    console.log(`Name: ${name}`);
    console.log(`Symbol: ${symbol}`);
    console.log(`Decimals: ${decimals}`);
    console.log(`Total Supply: ${formattedSupply} ${symbol}`);
    
    // Check owner balance
    const balance = await dove.balanceOf(deployer.address);
    const formattedBalance = ethers.utils.formatUnits(balance, decimals);
    console.log(`Your Balance: ${formattedBalance} ${symbol}`);
    
    console.log("\n=== Contract Info ===");
    console.log(`Token Contract: ${tokenAddress}`);
    console.log(`Admin Contract: ${adminAddress}`);
    console.log(`Fees Contract: ${feesAddress}`);
    
    console.log("\n=== Transfer Test ===");
    // Try a small transfer to diagnose issues
    try {
      // Create a different account to try a small transfer to
      const testAddress = ethers.Wallet.createRandom().address;
      console.log(`Attempting small test transfer of 1 token to: ${testAddress}`);
      
      // Transfer 1 token with 18 decimals
      const tx = await dove.transfer(testAddress, ethers.utils.parseUnits("1", decimals));
      console.log(`Transaction hash: ${tx.hash}`);
      await tx.wait();
      console.log("Test transfer succeeded!");
      
      // Check balance after transfer
      const balanceAfter = await dove.balanceOf(deployer.address);
      const formattedBalanceAfter = ethers.utils.formatUnits(balanceAfter, decimals);
      console.log(`Your Balance After Transfer: ${formattedBalanceAfter} ${symbol}`);
      
    } catch (error) {
      console.log(`Transfer test failed: ${error.message}`);
      
      // Examine error more closely for diagnostics
      if (error.message.includes("execution reverted")) {
        console.log("\nDetailed error analysis:");
        console.log("- Transaction was reverted by the contract");
        
        if (error.message.includes("paused")) {
          console.log("- Token appears to still be paused");
        } else if (error.message.includes("exceed")) {
          console.log("- Possible max transaction limit");
        } else if (error.message.includes("fee")) {
          console.log("- Possible fee calculation issue");
        } else if (error.message.includes("allowance")) {
          console.log("- Allowance issue (unlikely for direct transfer)");
        }
      }
    }
    
  } catch (error) {
    console.error(`Error checking token: ${error.message}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
