// Transfer tokens to a single allocation wallet
// Usage: npx hardhat run scripts/admin/transfer-single-wallet.js --network base

const { ethers } = require("hardhat");

async function main() {
  // Configuration - MODIFY THESE VARIABLES
  const tokenAddress = "0x7be8982c3f67B136a695874dF4536E603e8023a6"; // DOVE token address
  const recipientAddress = "0xd02AC8129309a9c24392d04Bf06d827eC25888Fe"; // Recipient wallet address
  const amountToSend = "900000000"; // Amount in tokens (without decimals) - sending 900M tokens
  const walletName = "Liquidity Provision"; // Name for logging

  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);
  
  // Get token contract
  const dove = await ethers.getContractAt("DOVE", tokenAddress);
  
  // Get token info
  const decimals = await dove.decimals();
  console.log(`Token decimals: ${decimals}`);
  
  // Convert amount to wei (with decimals)
  // Create a BigNumber directly with the correct number of zeros for decimals
  const amountInWei = ethers.BigNumber.from(amountToSend + "000000000000000000"); // Adding 18 zeros for decimals
  console.log(`Attempting to send ${amountToSend} DOVE to ${walletName} wallet (${recipientAddress})`);
  
  // Check sender balance
  const balance = await dove.balanceOf(deployer.address);
  const balanceFormatted = balance.toString() / 10**decimals;
  console.log(`Your balance: ${balanceFormatted} DOVE`);
  
  if (balance.lt(amountInWei)) {
    console.error(`Error: Your wallet doesn't have enough tokens. You need ${amountToSend} but only have ${balanceFormatted}`);
    return;
  }
  
  try {
    console.log(`Sending ${amountToSend} DOVE to ${recipientAddress}...`);
    const tx = await dove.transfer(recipientAddress, amountInWei, {
      gasLimit: 300000
    });
    console.log(`Transaction hash: ${tx.hash}`);
    console.log(`Waiting for confirmation...`);
    await tx.wait();
    console.log(`✅ Transfer complete!`);
    
    // Check recipient's balance after transfer
    const recipientBalance = await dove.balanceOf(recipientAddress);
    const recipientBalanceFormatted = recipientBalance.toString() / 10**decimals;
    console.log(`${walletName} wallet now has ${recipientBalanceFormatted} DOVE`);
  } catch (error) {
    console.error(`Error transferring tokens:`, error.message);
    
    // Provide help based on the error
    if (error.message.includes("TransferExceedsMaxAmount")) {
      console.log(`\n⚠️ The transfer exceeds the maximum transaction limit.`);
      console.log(`Try a smaller amount (e.g. 500000000 or 500M tokens).`);
    } else if (error.message.includes("TransferExceedsMaxWalletLimit")) {
      console.log(`\n⚠️ The transfer would cause the recipient to exceed the maximum wallet limit.`);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
