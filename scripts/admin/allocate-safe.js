// DOVE Token Allocation - Safe Distribution Script
// This script distributes tokens in a way that respects any existing limits
// Usage: npx hardhat run scripts/admin/allocate-safe.js --network base

const { ethers } = require("hardhat");

async function main() {
  // Contract addresses
  const tokenAddress = "0x7be8982c3f67B136a695874dF4536E603e8023a6"; // DOVE token
  
  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);
  
  // Get token contract
  const dove = await ethers.getContractAt("DOVE", tokenAddress);
  
  // Define allocation wallets with their allocations
  const wallets = [
    {
      name: "Founder/Team",
      address: "0x20a43d9D1969206E9778D890a3191361903252c0", 
      amount: "7500000000" // 7.5B
    },
    {
      name: "Liquidity Provision",
      address: "0xd02AC8129309a9c24392d04Bf06d827eC25888Fe", 
      amount: "38000000000" // 38B
    },
    {
      name: "Community & Airdrops",
      address: "0x083CA3260DA3018DF4EAFe910F45445ABF2c7897", 
      amount: "16000000000" // 16B
    },
    {
      name: "Ecosystem Development Fund",
      address: "0x35C8D89F79faee563B2ff272d66195016d6fdFc0", 
      amount: "10000000000" // 10B
    },
    {
      name: "Marketing & Partnerships",
      address: "0xD268D34DC023Bcb3C2300B60494A75b3a4022997", 
      amount: "7500000000" // 7.5B
    },
    {
      name: "CEX-Listing Reserve",
      address: "0x6Bb8d0a50D03B26F59037b0C18837018Af2af58E", 
      amount: "5000000000" // 5B
    },
    {
      name: "Bug-Bounty & Security",
      address: "0x88892C8d9E07c4c2F812356ce012e2ED585be5D7", 
      amount: "2500000000" // 2.5B
    },
    {
      name: "Treasury/Ops Buffer",
      address: "0xa689eaD23b671CAbF0E79cc59E0C8a6B937d5309", 
      amount: "3500000000" // 3.5B
    },
    {
      name: "Charity Pool",
      address: "0xb29984ef12F790B8908Bc1Ca17a9eD9238Aa46f7", 
      amount: "2000000000" // 2B
    },
    {
      name: "Referral/Promo Pool",
      address: "0x409b2254E9B09b162Db2f0b5621A0D06466B5C97", 
      amount: "1000000000" // 1B
    }
  ];
  
  // Get token info
  const decimals = await dove.decimals();
  console.log(`Token decimals: ${decimals}`);
  
  // Get current status
  const maxTxLimit = await dove.getMaxTransactionAmount();
  console.log(`Current max transaction limit: ${maxTxLimit.toString() / (10**decimals)} DOVE`);
  
  // Define safe chunk size (use 50% of max limit to be safe)
  const SAFE_CHUNK_SIZE = "500000000"; // 500M tokens, which should be less than 1% of total supply
  
  // Process for which wallets
  const START_INDEX = 0; // Start from this wallet (0-9)
  const END_INDEX = 9;   // Process until this wallet (0-9)
  
  // Check deployer balance
  const balance = await dove.balanceOf(deployer.address);
  console.log(`Your balance: ${balance.toString() / (10**decimals)} DOVE`);
  
  // Pause after each wallet - set to false for continuous operation
  const PAUSE_BETWEEN_WALLETS = true;
  
  console.log("\n===== ALLOCATION PROCESS STARTED =====\n");
  
  // Helper function to format numbers
  function formatTokens(wei) {
    return wei.toString() / (10**decimals);
  }
  
  for (let i = START_INDEX; i <= END_INDEX; i++) {
    const wallet = wallets[i];
    console.log(`\n[${i}] Processing ${wallet.name} wallet (${wallet.address})...`);
    
    // Check current balance
    const currentBalance = await dove.balanceOf(wallet.address);
    console.log(`Current balance: ${formatTokens(currentBalance)} DOVE`);
    
    // Convert to wei with decimals - add 18 zeros to the amount
    const targetAmount = ethers.BigNumber.from(wallet.amount + "000000000000000000");
    
    if (currentBalance.gte(targetAmount)) {
      console.log(`✅ ${wallet.name} wallet already has required tokens or more. Skipping.`);
      continue;
    }
    
    // Calculate remaining amount
    const remainingAmount = targetAmount.sub(currentBalance);
    console.log(`Remaining to transfer: ${formatTokens(remainingAmount)} DOVE`);
    
    // Calculate chunk size with 18 decimals
    const chunkSizeWei = ethers.BigNumber.from(SAFE_CHUNK_SIZE + "000000000000000000");
    const chunkCountRaw = remainingAmount.div(chunkSizeWei);
    const chunkCount = chunkCountRaw.gt(0) ? chunkCountRaw.toNumber() : 1;
    console.log(`Will transfer in ${chunkCount} chunk(s) of ${SAFE_CHUNK_SIZE} DOVE each`);
    
    // Confirm before proceeding
    if (PAUSE_BETWEEN_WALLETS || i === START_INDEX) {
      const readline = require('readline').createInterface({
        input: process.stdin,
        output: process.stdout
      });
      
      const proceed = await new Promise(resolve => {
        readline.question(`Continue with transfer to ${wallet.name}? (yes/no): `, answer => {
          readline.close();
          resolve(answer.toLowerCase() === 'yes');
        });
      });
      
      if (!proceed) {
        console.log(`Skipping transfer to ${wallet.name}`);
        continue;
      }
    }
    
    // Execute transfers
    let amountLeft = remainingAmount;
    let successfulTransfer = false;
    
    for (let j = 1; j <= chunkCount; j++) {
      // Calculate this chunk size
      const thisChunkSize = amountLeft.lt(chunkSizeWei) ? amountLeft : chunkSizeWei;
      
      console.log(`\n- Chunk ${j}/${chunkCount}: Sending ${formatTokens(thisChunkSize)} DOVE...`);
      
      try {
        const tx = await dove.transfer(wallet.address, thisChunkSize, {
          gasLimit: 300000
        });
        console.log(`Transaction hash: ${tx.hash}`);
        console.log(`Waiting for confirmation...`);
        await tx.wait();
        console.log(`✅ Chunk ${j} transferred successfully!`);
        
        // Update tracking
        amountLeft = amountLeft.sub(thisChunkSize);
        successfulTransfer = true;
        
        // Wait to avoid nonce issues
        if (j < chunkCount) {
          console.log(`Waiting 3 seconds before next chunk...`);
          await new Promise(resolve => setTimeout(resolve, 3000));
        }
      } catch (error) {
        console.error(`❌ Error transferring chunk ${j}:`, error.message);
        
        if (error.message.includes("TransferExceedsMaxAmount")) {
          console.log(`\n⚠️ Transfer exceeded maximum transaction limit.`);
          console.log(`Trying with a smaller amount (half size)...`);
          
          try {
            const halfChunk = thisChunkSize.div(2);
            console.log(`Sending ${formatTokens(halfChunk)} DOVE...`);
            
            const tx = await dove.transfer(wallet.address, halfChunk, {
              gasLimit: 300000
            });
            console.log(`Transaction hash: ${tx.hash}`);
            console.log(`Waiting for confirmation...`);
            await tx.wait();
            console.log(`✅ Smaller chunk transferred successfully!`);
            
            // Update tracking
            amountLeft = amountLeft.sub(halfChunk);
            successfulTransfer = true;
          } catch (error2) {
            console.error(`❌ Error transferring smaller chunk:`, error2.message);
            console.log(`\n⚠️ Suggesting to try an even smaller amount next time.`);
            break;
          }
        } else if (error.message.includes("TransferExceedsMaxWalletLimit")) {
          console.log(`\n⚠️ The transfer would cause the recipient to exceed the maximum wallet limit.`);
          console.log(`The wallet needs to be excluded from the max wallet limit first.`);
          break;
        } else {
          console.log(`\n⚠️ Unexpected error occurred. Consider these possibilities:`);
          console.log(`1. The transaction was reverted during fee processing`);
          console.log(`2. The contract may be paused`);
          console.log(`3. The gas limit might be too low`);
          break;
        }
      }
    }
    
    // Check final balance
    if (successfulTransfer) {
      const finalBalance = await dove.balanceOf(wallet.address);
      console.log(`\nFinal balance of ${wallet.name} wallet: ${formatTokens(finalBalance)} DOVE`);
      
      const percentage = finalBalance.mul(100).div(targetAmount);
      console.log(`Progress: ${percentage}% of allocation complete`);
      
      if (finalBalance.gte(targetAmount)) {
        console.log(`✅ ${wallet.name} wallet allocation COMPLETE!`);
      } else {
        console.log(`⚠️ ${wallet.name} wallet allocation PARTIAL. Will need more transfers.`);
      }
    }
  }
  
  console.log("\n===== ALLOCATION SUMMARY =====");
  for (const wallet of wallets) {
    const balance = await dove.balanceOf(wallet.address);
    const targetAmount = ethers.BigNumber.from(wallet.amount + "000000000000000000");
    const percentage = balance.mul(100).div(targetAmount);
    const status = balance.gte(targetAmount) ? "✅ COMPLETE" : "⚠️ PARTIAL";
    
    console.log(`${wallet.name}: ${formatTokens(balance)}/${wallet.amount} (${percentage}%) - ${status}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
