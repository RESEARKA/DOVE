import { ethers } from "hardhat";
import { verify } from "../utils/verify";

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
  const Dove = await ethers.getContractFactory("DOVE");
  const dove = await Dove.deploy(charityWallet);
  await dove.deployed();
  
  console.log(`DOVE token deployed at: ${dove.address}`);
  
  // Verify contract on block explorer if not on a local network
  const { chainId } = await ethers.provider.getNetwork();
  if (chainId !== 31337) { // Not localhost
    console.log("Waiting for block confirmations...");
    await dove.deployTransaction.wait(6); // Wait for 6 confirmations
    
    await verify(dove.address, [charityWallet]);
    console.log("Contract verified on BaseScan");
  }
  
  // If deployer isn't the final owner, transfer ownership to multisig
  if (deployer.address !== multisigAddress) {
    console.log(`Transferring ownership to multisig: ${multisigAddress}`);
    await dove.transferOwnership(multisigAddress);
    console.log("Ownership transferred to multisig");
  }
  
  return { dove, deployer };
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
