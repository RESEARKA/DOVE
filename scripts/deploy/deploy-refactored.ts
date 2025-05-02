import { ethers } from "hardhat";
import { verify } from "../utils/verify";

/**
 * Deploy refactored DOVE token contracts to the Base Sepolia testnet
 * Usage: `pnpm hardhat run scripts/deploy/deploy-refactored.ts --network baseSepolia`
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
  
  // Step 1: Deploy DOVEFees contract
  console.log("Deploying DOVEFees contract...");
  const DOVEFeesFactory = await ethers.getContractFactory("core/DOVEFees");
  const feeManager = await DOVEFeesFactory.deploy(charityWallet);
  const feesAddress = await feeManager.getAddress();
  console.log(`DOVEFees deployed at: ${feesAddress}`);
  
  // Step 2: Deploy DOVEAdmin contract
  console.log("Deploying DOVEAdmin contract...");
  const DOVEAdminFactory = await ethers.getContractFactory("core/DOVEAdmin");
  const adminManager = await DOVEAdminFactory.deploy(feesAddress);
  const adminAddress = await adminManager.getAddress();
  console.log(`DOVEAdmin deployed at: ${adminAddress}`);
  
  // Step 3: Deploy DOVEToken contract with the addresses of the management contracts
  console.log("Deploying DOVEToken contract...");
  const DOVETokenFactory = await ethers.getContractFactory("DOVEToken");
  const dove = await DOVETokenFactory.deploy(adminAddress, feesAddress);
  const doveAddress = await dove.getAddress();
  console.log(`DOVEToken deployed at: ${doveAddress}`);
  
  // Verify contracts on block explorer if not on a local network
  const { chainId } = await ethers.provider.getNetwork();
  if (chainId !== 31337n) { // Not localhost
    console.log("Waiting for block confirmations...");
    
    // Wait for confirmations for each contract
    const feeTx = feeManager.deploymentTransaction();
    if (feeTx) await feeTx.wait(6);
    
    const adminTx = adminManager.deploymentTransaction();
    if (adminTx) await adminTx.wait(6);
    
    const doveTx = dove.deploymentTransaction();
    if (doveTx) await doveTx.wait(6);
    
    // Verify contracts
    console.log("Verifying contracts on BaseScan...");
    
    try {
      // Verify DOVEFees contract
      await verify(feesAddress, [charityWallet]);
      console.log("DOVEFees contract verified on BaseScan");
      
      // Verify DOVEAdmin contract
      await verify(adminAddress, [feesAddress]);
      console.log("DOVEAdmin contract verified on BaseScan");
      
      // Verify the main token contract
      await verify(doveAddress, [adminAddress, feesAddress]);
      console.log("DOVEToken contract verified on BaseScan");
    } catch (error) {
      console.log("Warning: Contract verification failed. You may need to verify them manually.");
      console.error(error);
    }
  }
  
  // Print ownership transfer instructions
  if (deployer.address !== multisigAddress) {
    console.log(`\nIMPORTANT: Transfer ownership to multisig (${multisigAddress}) using these commands:`);
    console.log(`\n1. For DOVEFees (${feesAddress}):`);
    console.log(`   npx hardhat --network baseSepolia run scripts/admin/transfer-ownership.js --contract ${feesAddress} --new-owner ${multisigAddress}`);
    
    console.log(`\n2. For DOVEAdmin (${adminAddress}):`);
    console.log(`   npx hardhat --network baseSepolia run scripts/admin/transfer-ownership.js --contract ${adminAddress} --new-owner ${multisigAddress}`);
    
    console.log(`\n3. For DOVEToken (${doveAddress}):`);
    console.log(`   npx hardhat --network baseSepolia run scripts/admin/grant-role.js --contract ${doveAddress} --role DEFAULT_ADMIN_ROLE --account ${multisigAddress}`);
    console.log(`   npx hardhat --network baseSepolia run scripts/admin/revoke-role.js --contract ${doveAddress} --role DEFAULT_ADMIN_ROLE --account ${deployer.address}`);
  }
  
  return { 
    dove: doveAddress,
    feeManager: feesAddress,
    adminManager: adminAddress
  };
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
