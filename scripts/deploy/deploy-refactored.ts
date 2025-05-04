import { ethers } from "hardhat";
import { verify } from "../utils/verify";

/**
 * Deploy DOVE token contracts to the Base Sepolia testnet
 * Usage: `npx hardhat run scripts/deploy/deploy-refactored.ts --network baseSepolia`
 * 
 * Follows DOVE Developer Guidelines Section 7 - Deployment Flow
 */
export async function deployRefactoredDove() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying DOVE token with the account: ${deployer.address}`);

  // Get multisig address from environment (or use deployer for testing)
  const multisigAddress = process.env.MULTISIG_ADDRESS || deployer.address;
  
  // Get charity wallet address from environment (or use multisig as fallback)
  const charityWallet = process.env.CHARITY_WALLET_ADDRESS || multisigAddress;
  
  console.log(`Using charity wallet: ${charityWallet}`);
  console.log(`Using deployer address for initial supply: ${deployer.address}`);
  
  // Step 1: Deploy DOVEAdmin contract first
  console.log("Deploying DOVEAdmin contract...");
  const DOVEAdminFactory = await ethers.getContractFactory("DOVEAdmin");
  const adminManager = await DOVEAdminFactory.deploy(deployer.address);
  await adminManager.deploymentTransaction()?.wait(1);
  const adminAddress = await adminManager.getAddress();
  console.log(`DOVEAdmin deployed at: ${adminAddress}`);
  
  // Step 2: Deploy DOVE token
  console.log("Deploying DOVE token contract...");
  const DOVETokenFactory = await ethers.getContractFactory("DOVE");
  const dove = await DOVETokenFactory.deploy(adminAddress, charityWallet, deployer.address);
  await dove.deploymentTransaction()?.wait(1);
  const doveAddress = await dove.getAddress();
  console.log(`DOVE token deployed at: ${doveAddress}`);
  
  // Step 3: Deploy DOVEFees contract with token address
  console.log("Deploying DOVEFees contract...");
  const DOVEFeesFactory = await ethers.getContractFactory("DOVEFees");
  const feeManager = await DOVEFeesFactory.deploy(doveAddress, charityWallet);
  await feeManager.deploymentTransaction()?.wait(1);
  const feesAddress = await feeManager.getAddress();
  console.log(`DOVEFees deployed at: ${feesAddress}`);
  
  // Verify contracts on block explorer if not on a local network
  const { chainId } = await ethers.provider.getNetwork();
  if (chainId !== 31337n) { // Not localhost
    console.log("Waiting for block confirmations...");
    
    // Wait for additional confirmations
    await adminManager.deploymentTransaction()?.wait(5);
    await dove.deploymentTransaction()?.wait(5);
    await feeManager.deploymentTransaction()?.wait(5);
    
    // Verify contracts
    console.log("Verifying contracts on BaseScan...");
    
    try {
      // Verify DOVEAdmin contract
      await verify(adminAddress, [deployer.address]);
      console.log("DOVEAdmin contract verified on BaseScan");
      
      // Verify the main token contract
      await verify(doveAddress, [adminAddress, charityWallet, deployer.address]);
      console.log("DOVE token contract verified on BaseScan");
      
      // Verify DOVEFees contract
      await verify(feesAddress, [doveAddress, charityWallet]);
      console.log("DOVEFees contract verified on BaseScan");
    } catch (error) {
      console.log("Warning: Contract verification failed. You may need to verify them manually.");
      console.error(error);
    }
    
    // Print post-deployment instructions
    console.log("\n=== Post-Deployment Actions ===");
    console.log("Run the following commands to initialize the contracts:");
    
    console.log(`\n1. Initialize DOVE token with contracts:`);
    console.log(`   npx hardhat --network baseSepolia run scripts/admin/initialize-token.js --token ${doveAddress} --fees ${feesAddress}`);
    
    console.log(`\n2. For DOVEAdmin (${adminAddress}):`);
    console.log(`   npx hardhat --network baseSepolia run scripts/admin/transfer-ownership.js --contract ${adminAddress} --new-owner ${multisigAddress}`);
    
    console.log(`\n3. For DOVE token (${doveAddress}):`);
    console.log(`   npx hardhat --network baseSepolia run scripts/admin/grant-role.js --contract ${doveAddress} --role DEFAULT_ADMIN_ROLE --account ${multisigAddress}`);
    console.log(`   npx hardhat --network baseSepolia run scripts/admin/revoke-role.js --contract ${doveAddress} --role DEFAULT_ADMIN_ROLE --account ${deployer.address}`);
  }
  
  return { adminManager, dove, feeManager };
}

// Auto-execute if script is run directly
if (require.main === module) {
  deployRefactoredDove()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
