// Script to send multiple transactions for token distribution
// Usage: npx hardhat run scripts/admin/multiple-transfers.js --network base

const { ethers } = require("hardhat");

async function main() {
  // Configuration
  const tokenAddress = "0x7be8982c3f67B136a695874dF4536E603e8023a6";
  
  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);
  
  // Connect to token
  const dove = await ethers.getContractAt("DOVE", tokenAddress);
  
  // Define allocations - each send will be split into 1B chunks
  const allocations = [
    {
      name: "Treasury",
      address: "0xa689eaD23b671cAbF0E79cc59E0C8a6B937d5309",
      amount: "3500000000" // 3.5B
    },
    {
      name: "Founder/Team",
      address: "0x20a43d9D1969206F9778D890a31913619032520c",
      amount: "7500000000" // 7.5B
    },
    {
      name: "Liquidity",
      address: "0xd02AC8129309a9c2439a7122d04Bf06a82725968Fe",
      amount: "38000000000" // 38B
    },
    {
      name: "Community",
      address: "0x083CA260DA3018DF4EAFe910F4545ABF2c7897",
      amount: "16000000000" // 16B
    },
    {
      name: "Ecosystem",
      address: "0x35C8D89F79faee563B2ff272d6619501616d6fdc0",
      amount: "10000000000" // 10B
    },
    {
      name: "Marketing",
      address: "0xD268D34DC023Bcb3C2300B6049A475b3d402297",
      amount: "7500000000" // 7.5B
    },
    // Add other allocations as needed
  ];
  
  // Max transaction amount (1B)
  const MAX_TX = ethers.utils.parseUnits("1000000000", 18);
  
  // Process each allocation
  for (const allocation of allocations) {
    console.log(`\nProcessing ${allocation.name} allocation: ${allocation.amount} DOVE`);
    
    // Parse total amount to send
    const totalAmount = ethers.utils.parseUnits(allocation.amount, 18);
    
    // Calculate how many full transactions of MAX_TX are needed
    const fullTxCount = totalAmount.div(MAX_TX);
    
    // Calculate remainder for final transaction
    const remainder = totalAmount.mod(MAX_TX);
    
    console.log(`This will be split into ${fullTxCount.toString()} transactions of 1B each, plus ${ethers.utils.formatUnits(remainder, 18)} DOVE`);
    
    // Get current balance
    const startBalance = await dove.balanceOf(allocation.address);
    console.log(`Starting balance of ${allocation.name}: ${ethers.utils.formatUnits(startBalance, 18)} DOVE`);
    
    // Ask for confirmation before proceeding
    console.log(`Ready to transfer ${allocation.amount} DOVE to ${allocation.name} (${allocation.address})`);
    const readline = require('readline').createInterface({
      input: process.stdin,
      output: process.stdout
    });
    
    // Wait for confirmation
    await new Promise(resolve => {
      readline.question('Type "yes" to proceed with this allocation, or any other key to skip: ', answer => {
        readline.close();
        if (answer.toLowerCase() === 'yes') {
          console.log('Proceeding with transfer...');
          resolve(true);
        } else {
          console.log('Skipping this allocation.');
          resolve(false);
        }
      });
    }).then(async (proceed) => {
      if (!proceed) return;
      
      // Send full transactions
      for (let i = 0; i < fullTxCount.toNumber(); i++) {
        console.log(`Sending transaction ${i+1}/${fullTxCount.toString()} of 1B DOVE...`);
        try {
          const tx = await dove.transfer(allocation.address, MAX_TX, {
            gasLimit: 300000 // Higher gas limit
          });
          console.log(`Transaction hash: ${tx.hash}`);
          await tx.wait();
          console.log('Transfer complete!');
        } catch (error) {
          console.error(`Error in transaction ${i+1}: ${error.message}`);
          if (error.message.includes("execution reverted")) {
            console.log("This may be due to transaction limits or other contract restrictions.");
          }
          // Ask whether to continue with remaining transactions
          const continueRL = require('readline').createInterface({
            input: process.stdin,
            output: process.stdout
          });
          
          const shouldContinue = await new Promise(resolve => {
            continueRL.question('Continue with remaining transactions? (yes/no): ', answer => {
              continueRL.close();
              resolve(answer.toLowerCase() === 'yes');
            });
          });
          
          if (!shouldContinue) {
            console.log('Aborting remaining transactions for this allocation.');
            return;
          }
        }
        
        // Small delay between transactions
        await new Promise(r => setTimeout(r, 2000));
      }
      
      // Send remainder if any
      if (remainder.gt(0)) {
        console.log(`Sending remainder of ${ethers.utils.formatUnits(remainder, 18)} DOVE...`);
        try {
          const tx = await dove.transfer(allocation.address, remainder, {
            gasLimit: 300000
          });
          console.log(`Transaction hash: ${tx.hash}`);
          await tx.wait();
          console.log('Remainder transfer complete!');
        } catch (error) {
          console.error(`Error sending remainder: ${error.message}`);
        }
      }
      
      // Get final balance
      const endBalance = await dove.balanceOf(allocation.address);
      console.log(`\nFinal balance of ${allocation.name}: ${ethers.utils.formatUnits(endBalance, 18)} DOVE`);
      console.log(`Total transferred: ${ethers.utils.formatUnits(endBalance.sub(startBalance), 18)} DOVE`);
    });
  }
  
  console.log("\nAll allocations processed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
