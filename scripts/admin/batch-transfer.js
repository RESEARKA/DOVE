// Batch transfer tokens to allocation wallets in chunks that work within the limits
// Usage: npx hardhat run scripts/admin/batch-transfer.js --network base

const { ethers } = require("hardhat");

async function main() {
  // Contract addresses
  const tokenAddress = "0x7be8982c3f67B136a695874dF4536E603e8023a6"; // DOVE token address
  
  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);
  
  // Get token contract
  const dove = await ethers.getContractAt("DOVE", tokenAddress);
  
  // Get token info
  const decimals = await dove.decimals();
  console.log(`Token decimals: ${decimals}`);
  const maxTxLimit = await dove.getMaxTransactionAmount();
  console.log(`Max transaction limit: ${maxTxLimit.toString() / 10**decimals}`);
  
  // Define allocation wallets with their allocations
  const wallets = [
    {
      name: "Founder/Team",
      address: "0x20a43d9D1969206E9778D890a3191361903252c0", 
      amount: ethers.BigNumber.from("7500000000000000000000000000") // 7.5B with 18 decimals
    },
    {
      name: "Liquidity Provision",
      address: "0xd02AC8129309a9c24392d04Bf06d827eC25888Fe", 
      amount: ethers.BigNumber.from("38000000000000000000000000000") // 38B with 18 decimals
    },
    {
      name: "Community & Airdrops",
      address: "0x083CA3260DA3018DF4EAFe910F45445ABF2c7897", 
      amount: ethers.BigNumber.from("16000000000000000000000000000") // 16B with 18 decimals
    },
    {
      name: "Ecosystem Development Fund",
      address: "0x35C8D89F79faee563B2ff272d66195016d6fdFc0", 
      amount: ethers.BigNumber.from("10000000000000000000000000000") // 10B with 18 decimals
    },
    {
      name: "Marketing & Partnerships",
      address: "0xD268D34DC023Bcb3C2300B60494A75b3a4022997", 
      amount: ethers.BigNumber.from("7500000000000000000000000000") // 7.5B with 18 decimals
    },
    {
      name: "CEX-Listing Reserve",
      address: "0x6Bb8d0a50D03B26F59037b0C18837018Af2af58E", 
      amount: ethers.BigNumber.from("5000000000000000000000000000") // 5B with 18 decimals
    },
    {
      name: "Bug-Bounty & Security",
      address: "0x88892C8d9E07c4c2F812356ce012e2ED585be5D7", 
      amount: ethers.BigNumber.from("2500000000000000000000000000") // 2.5B with 18 decimals
    },
    {
      name: "Treasury/Ops Buffer",
      address: "0xa689eaD23b671CAbF0E79cc59E0C8a6B937d5309", 
      amount: ethers.BigNumber.from("3500000000000000000000000000") // 3.5B with 18 decimals
    },
    {
      name: "Charity Pool",
      address: "0xb29984ef12F790B8908Bc1Ca17a9eD9238Aa46f7", 
      amount: ethers.BigNumber.from("2000000000000000000000000000") // 2B with 18 decimals
    },
    {
      name: "Referral/Promo Pool",
      address: "0x409b2254E9B09b162Db2f0b5621A0D06466B5C97", 
      amount: ethers.BigNumber.from("1000000000000000000000000000") // 1B with 18 decimals
    }
  ];
  
  // Safe batch size - 50% of max to be safe
  const safeChunkSize = maxTxLimit.div(2);
  
  // Process for the specified wallet index only - can be used to resume from a specific wallet if needed
  const walletToProcess = -1; // -1 means process all wallets, 0-9 means process specific wallet
  
  // Calculate total to transfer
  let totalToTransfer = ethers.BigNumber.from(0);
  for (const wallet of wallets) {
    totalToTransfer = totalToTransfer.add(wallet.amount);
  }
  console.log(`Total tokens to allocate: ${totalToTransfer.toString() / 10**decimals}`);
  
  // Check if we have enough tokens
  const balance = await dove.balanceOf(deployer.address);
  console.log(`Your balance: ${balance.toString() / 10**decimals}`);
  
  if (balance.lt(totalToTransfer)) {
    console.error(`Error: Your wallet doesn't have enough tokens. You need ${totalToTransfer.toString() / 10**decimals} but only have ${balance.toString() / 10**decimals}`);
    return;
  }
  
  // Process each wallet
  for (let i = 0; i < wallets.length; i++) {
    if (walletToProcess !== -1 && walletToProcess !== i) {
      console.log(`Skipping wallet ${i}: ${wallets[i].name}`);
      continue;
    }
    
    const wallet = wallets[i];
    console.log(`\nProcessing ${wallet.name} wallet (${wallet.address})...`);
    console.log(`Total to transfer: ${wallet.amount.toString() / 10**decimals}`);
    
    // Check current balance
    const currentBalance = await dove.balanceOf(wallet.address);
    console.log(`Current balance: ${currentBalance.toString() / 10**decimals}`);
    
    if (currentBalance.gte(wallet.amount)) {
      console.log(`✅ This wallet already has the required amount or more. Skipping.`);
      continue;
    }
    
    // Calculate remaining amount
    const remainingAmount = wallet.amount.sub(currentBalance);
    console.log(`Remaining to transfer: ${remainingAmount.toString() / 10**decimals}`);
    
    // Transfer in chunks
    let amountLeft = remainingAmount;
    let chunkCount = 1;
    
    while (amountLeft.gt(0)) {
      const chunkSize = amountLeft.lt(safeChunkSize) ? amountLeft : safeChunkSize;
      console.log(`\nChunk ${chunkCount}: Transferring ${chunkSize.toString() / 10**decimals} tokens...`);
      
      try {
        const tx = await dove.transfer(wallet.address, chunkSize, {
          gasLimit: 300000
        });
        console.log(`Transaction hash: ${tx.hash}`);
        console.log(`Waiting for confirmation...`);
        await tx.wait();
        console.log(`✅ Chunk ${chunkCount} successfully transferred!`);
        
        // Update amount left
        amountLeft = amountLeft.sub(chunkSize);
        console.log(`Remaining after this chunk: ${amountLeft.toString() / 10**decimals}`);
        chunkCount++;
        
        // Wait 2 seconds between chunks to avoid nonce issues
        await new Promise(resolve => setTimeout(resolve, 2000));
      } catch (error) {
        console.error(`Error transferring chunk ${chunkCount}:`, error.message);
        
        // If error indicates transaction reverted, try with a smaller chunk
        if (error.message.includes("reverted")) {
          console.log(`\nTransaction reverted, trying with half the chunk size...`);
          const smallerChunk = chunkSize.div(2);
          console.log(`New chunk size: ${smallerChunk.toString() / 10**decimals}`);
          
          try {
            const tx2 = await dove.transfer(wallet.address, smallerChunk, {
              gasLimit: 300000
            });
            console.log(`Transaction hash: ${tx2.hash}`);
            console.log(`Waiting for confirmation...`);
            await tx2.wait();
            console.log(`✅ Smaller chunk ${chunkCount} successfully transferred!`);
            
            // Update amount left
            amountLeft = amountLeft.sub(smallerChunk);
            console.log(`Remaining after this chunk: ${amountLeft.toString() / 10**decimals}`);
            chunkCount++;
          } catch (error2) {
            console.error(`Error transferring smaller chunk:`, error2.message);
            console.log(`\n⚠️ Stopping process for this wallet. Please check transaction limits and try again later.`);
            break;
          }
        } else {
          console.log(`\n⚠️ Stopping process for this wallet. Error not related to transaction limits.`);
          break;
        }
      }
    }
    
    // Check final balance
    const finalBalance = await dove.balanceOf(wallet.address);
    console.log(`\nFinal balance of ${wallet.name} wallet: ${finalBalance.toString() / 10**decimals}`);
    
    if (finalBalance.gte(wallet.amount)) {
      console.log(`✅ ${wallet.name} wallet allocation complete!`);
    } else {
      console.log(`⚠️ ${wallet.name} wallet allocation incomplete. Transferred ${finalBalance.sub(currentBalance).toString() / 10**decimals} out of ${remainingAmount.toString() / 10**decimals} remaining.`);
    }
  }
  
  console.log("\n==== Distribution Summary ====");
  for (const wallet of wallets) {
    const balance = await dove.balanceOf(wallet.address);
    const expected = wallet.amount;
    const status = balance.gte(expected) ? "✅ COMPLETE" : "⚠️ INCOMPLETE";
    console.log(`${wallet.name}: ${balance.toString() / 10**decimals}/${expected.toString() / 10**decimals} - ${status}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
