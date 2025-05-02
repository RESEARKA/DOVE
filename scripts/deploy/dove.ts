import { ethers } from "hardhat";
import { verify } from "../utils/verify";
import { DOVE } from "../../typechain-types";

/**
 * Deploy DOVE token contract to the Base network
 * Usage: `pnpm hardhat run scripts/deploy/dove.ts --network base`
 * 
 * Follows DOVE Developer Guidelines Section 7 - Deployment Flow
 */
export async function deployDove() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying DOVE token with the account: ${deployer.address}`);

  // Get multisig address from environment (or use deployer for testing)
  const multisigAddress = process.env.MULTISIG_ADDRESS || deployer.address;
  
  // Get charity wallet address from environment (or use multisig as fallback)
  const charityWallet = process.env.CHARITY_WALLET_ADDRESS || multisigAddress;
  
  console.log(`Using charity wallet: ${charityWallet}`);
  
  // Deploy DOVE contract with charity wallet parameter
  // This will automatically deploy DOVEFees and DOVEAdmin as part of the constructor
  const Dove = await ethers.getContractFactory("DOVE");
  const dove = await Dove.deploy(charityWallet) as DOVE;
  const doveAddress = await dove.getAddress();
  
  console.log(`DOVE token deployed at: ${doveAddress}`);

  // Get addresses of the module contracts
  const feesAddress = await dove.feeManager();
  const adminAddress = await dove.adminManager();
  
  console.log(`DOVEFees deployed at: ${feesAddress}`);
  console.log(`DOVEAdmin deployed at: ${adminAddress}`);
  
  // Verify contract on block explorer if not on a local network
  const { chainId } = await ethers.provider.getNetwork();
  if (chainId !== 31337n) { // Not localhost
    console.log("Waiting for block confirmations...");
    const tx = dove.deploymentTransaction();
    if (tx) await tx.wait(6); // Wait for 6 confirmations
    
    // Verify the main token contract
    await verify(doveAddress, [charityWallet]);
    console.log("DOVE contract verified on BaseScan");
    
    // Verify module contracts
    try {
      // Verify DOVEFees contract
      await verify(feesAddress, [charityWallet]);
      console.log("DOVEFees contract verified on BaseScan");
      
      // Verify DOVEAdmin contract
      await verify(adminAddress, [feesAddress]);
      console.log("DOVEAdmin contract verified on BaseScan");
    } catch (error) {
      console.log("Warning: Verification of module contracts failed. You may need to verify them manually.");
      console.error(error);
    }
  }
  
  // If deployer isn't the final owner, transfer ownership to multisig
  // Note: Ownership of the module contracts is already transferred in the DOVE constructor
  if (deployer.address !== multisigAddress) {
    console.log(`\nTransferring ownership to multisig: ${multisigAddress}`);
    
    try {
      // Using ethers v6 interface syntax
      const ownableInterface = ethers.Interface.from([
        "function transferOwnership(address newOwner)"
      ]);
      
      // Create transaction data
      const data = ownableInterface.encodeFunctionData(
        "transferOwnership", [multisigAddress]
      );
      
      // Send transaction
      const tx = await deployer.sendTransaction({
        to: doveAddress,
        data
      });
      
      await tx.wait();
      console.log("Ownership transfer initiated. Multisig must accept ownership.");
      
      console.log(`\nIMPORTANT: The multisig wallet (${multisigAddress}) must call acceptOwnership() on:`);
      console.log(`1. Main token contract: ${doveAddress}`);
      console.log(`2. DOVEFees contract: ${feesAddress}`);
      console.log(`3. DOVEAdmin contract: ${adminAddress}`);
    } catch (error) {
      console.error("Error transferring ownership:", error);
      console.log("You may need to transfer ownership manually after deployment.");
    }
  }
  
  return { 
    dove, 
    feeManager: feesAddress,
    adminManager: adminAddress,
    deployer 
  };
}

// Auto-execute if script is run directly
if (require.main === module) {
  deployDove()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
}
