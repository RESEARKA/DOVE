// Simple DOVE Token Transfer Script - Sends a fixed amount to one wallet
// Usage: npx hardhat run scripts/admin/simple-send.js --network base

const { ethers } = require("hardhat");

async function main() {
  // =========== CONFIGURATION - EDIT THESE VALUES ===========
  
  // Target wallet - ONE of your allocation wallets
  const recipientAddress = "0xd02AC8129309a9c24392d04Bf06d827eC25888Fe"; // Liquidity wallet
  const recipientName = "Liquidity Provision";
  
  // Transfer amount - start small (100 million with 18 decimals)
  // For 100 million tokens, we need to append 18 zeros for decimals
  const amount = "100000000000000000000000000"; // 100 million tokens with 18 decimals
  const displayAmount = "100000000"; // For console output only - 100 million tokens
  
  // DOVE token contract address
  const tokenAddress = "0x7be8982c3f67B136a695874dF4536E603e8023a6";
  
  // =========== EXECUTION CODE - NO NEED TO EDIT BELOW ===========
  
  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);
  
  // Get token contract
  const dove = await ethers.getContractAt("DOVE", tokenAddress);
  
  // Get token info
  const decimals = await dove.decimals();
  console.log(`Token decimals: ${decimals}`);
  
  // Convert amount to BigNumber
  const amountBN = ethers.BigNumber.from(amount);
  console.log(`Attempting to send ${displayAmount} DOVE to ${recipientName} wallet (${recipientAddress})`);
  
  // Check if sender has enough tokens
  const balance = await dove.balanceOf(deployer.address);
  console.log(`Your balance: ${balance.toString()} (raw value with ${decimals} decimals)`);
  
  if (balance.lt(amountBN)) {
    console.error(`Error: Your balance is insufficient for this transfer.`);
    return;
  }
  
  // Confirm transfer
  const readline = require('readline').createInterface({
    input: process.stdin,
    output: process.stdout
  });
  
  await new Promise(resolve => {
    readline.question(`Confirm sending ${displayAmount} DOVE to ${recipientAddress}? (yes/no): `, answer => {
      readline.close();
      if (answer.toLowerCase() !== 'yes') {
        console.log('Transfer cancelled.');
        process.exit(0);
      }
      resolve();
    });
  });
  
  // Execute transfer
  try {
    console.log(`\nExecuting transfer...`);
    const tx = await dove.transfer(recipientAddress, amountBN, {
      gasLimit: 300000
    });
    console.log(`Transaction hash: ${tx.hash}`);
    console.log(`Waiting for confirmation...`);
    
    await tx.wait();
    console.log(`\n✅ Transfer successful!`);
    
    // Check new balance
    const newBalance = await dove.balanceOf(recipientAddress);
    console.log(`${recipientName} new balance: ${newBalance.toString()} (raw value with ${decimals} decimals)`);
    
  } catch (error) {
    console.error(`\n❌ Error during transfer:`, error.message);
    
    if (error.message.includes("TransferExceedsMaxAmount")) {
      console.log(`\nThe transfer exceeds the maximum transaction amount.`);
      console.log(`Try a smaller amount, like 10000000 (10 million tokens).`);
    } 
    else if (error.message.includes("TransferExceedsMaxWalletLimit")) {
      console.log(`\nThe transfer would cause the recipient to exceed the maximum wallet limit.`);
      console.log(`The wallet needs to be excluded from max wallet limit first.`);
    }
    else if (error.message.includes("paused")) {
      console.log(`\nThe contract is currently paused. It needs to be unpaused first.`);
    }
    else {
      console.log(`\nGeneral transfer error. Consider these possibilities:`);
      console.log(`1. The transfer was reverted during fee processing`);
      console.log(`2. The gas limit might be too low`);
      console.log(`3. There might be some other contract limitation`);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
