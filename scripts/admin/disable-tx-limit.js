// Disables the maximum transaction limit in the DOVE token
// Usage: npx hardhat run scripts/admin/disable-tx-limit.js --network base

const { ethers } = require("hardhat");

async function main() {
  // Contract addresses
  const adminAddress = "0x8527DD7b9CF030Ae2D38091FED33D01bC3b13693";
  
  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);
  
  // Get admin contract instance
  const admin = await ethers.getContractAt("DOVEAdmin", adminAddress);
  
  console.log("Attempting to disable max transaction limit directly...");
  
  console.log("\nThis will permanently disable the max transaction limit.");
  console.log("This means there will be no limit on how many tokens can be transferred in a single transaction.");
  console.log("This is useful for distributing tokens to allocation wallets.");
  console.log("\nHowever, there may be a timelock on this function, requiring a waiting period.");
  
  // User confirmation
  const readline = require('readline').createInterface({
    input: process.stdin,
    output: process.stdout
  });
  
  await new Promise(resolve => {
    readline.question('Type "yes" to proceed with disabling the max transaction limit: ', answer => {
      readline.close();
      if (answer.toLowerCase() === 'yes') {
        resolve(true);
      } else {
        console.log('Operation cancelled.');
        resolve(false);
        process.exit(0);
      }
    });
  });
  
  console.log("Disabling max transaction limit...");
  try {
    const tx = await admin.disableMaxTxLimit({
      gasLimit: 300000
    });
    console.log(`Transaction hash: ${tx.hash}`);
    console.log("Waiting for transaction confirmation...");
    await tx.wait();
    console.log("✅ Max transaction limit disabled successfully!");
    console.log("\nYou can now transfer tokens in any amount without any per-transaction limit.");
    console.log("This change is permanent and cannot be reversed.");
  } catch (error) {
    console.error("Error disabling max transaction limit:", error.message);
    
    if (error.message.includes("Timelock not elapsed")) {
      console.log("\n⚠️ This function requires a timelock period.");
      console.log("You need to schedule this operation and wait for the timelock to elapse before executing it.");
      console.log("\nWould you like to schedule the timelock for this operation?");
      
      const scheduleReadline = require('readline').createInterface({
        input: process.stdin,
        output: process.stdout
      });
      
      await new Promise(resolve => {
        scheduleReadline.question('Type "yes" to schedule the timelock for disabling max tx limit: ', async answer => {
          scheduleReadline.close();
          if (answer.toLowerCase() === 'yes') {
            try {
              console.log("Scheduling timelock for disabling max transaction limit...");
              const scheduleTx = await admin.scheduleOperation(
                3, // DISABLE_TX_LIMIT_OP code from contract
                {
                  gasLimit: 300000
                }
              );
              console.log(`Schedule transaction hash: ${scheduleTx.hash}`);
              await scheduleTx.wait();
              console.log("✅ Timelock scheduled successfully!");
              console.log("\nYou need to wait for the timelock period (typically 24 hours) to elapse.");
              console.log("After that, run this script again to execute the operation.");
            } catch (scheduleError) {
              console.error("Error scheduling timelock:", scheduleError.message);
            }
          } else {
            console.log('Scheduling cancelled.');
          }
          resolve(true);
        });
      });
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
