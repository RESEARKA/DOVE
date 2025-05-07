// Simple token transfer script for DOVE allocations
// Usage: npx hardhat run scripts/admin/simple-transfer.js --network base

async function main() {
  // Configuration - MODIFY THESE VALUES
  const tokenAddress = "0x7be8982c3f67B136a695874dF4536E603e8023a6"; // DOVE token address
  const recipientAddress = "0xd02AC8129309a9c24392d04Bf06d827eC25888Fe"; // Recipient wallet address
  const amountTokens = 900000000; // 900 million tokens (number without decimals)
  const walletName = "Liquidity Provision"; // Name for logging only

  // Hardhat imports
  const hre = require("hardhat");
  
  // Get signer
  const [deployer] = await hre.ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);
  
  // Get token contract
  const DOVE = await hre.ethers.getContractFactory("DOVE");
  const dove = await DOVE.attach(tokenAddress);
  
  // Get token info
  const decimals = await dove.decimals();
  console.log(`Token decimals: ${decimals}`);
  
  // Calculate amount with decimals
  const amount = hre.ethers.BigNumber.from(amountTokens).mul(
    hre.ethers.BigNumber.from(10).pow(decimals)
  );
  
  console.log(`Sending ${amountTokens} DOVE tokens to ${walletName} wallet (${recipientAddress})`);
  
  try {
    // Execute transfer
    const tx = await dove.transfer(recipientAddress, amount, {
      gasLimit: 300000
    });
    
    console.log(`Transaction submitted with hash: ${tx.hash}`);
    console.log(`Waiting for confirmation...`);
    
    // Wait for transaction to be mined
    await tx.wait();
    console.log(`✅ Transfer completed successfully!`);
    
  } catch (error) {
    console.error(`❌ Error during transfer:`, error.message);
    
    if (error.message.includes("transfer amount exceeds balance")) {
      console.log(`Your wallet doesn't have enough tokens to complete this transfer.`);
    } 
    else if (error.message.includes("TransferExceedsMaxAmount")) {
      console.log(`The transfer exceeds the maximum transaction limit. Try a smaller amount.`);
    }
    else if (error.message.includes("TransferExceedsMaxWalletLimit")) {
      console.log(`The transfer would cause the recipient to exceed the maximum wallet limit.`);
      console.log(`The wallet needs to be excluded from the max wallet limit first.`);
    }
  }
}

// Execute script
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
