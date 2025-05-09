import { ethers } from 'hardhat';
import { deployDove } from './deploy/dove';
import { DOVEFees } from '../typechain-types';

/**
 * Test script for deploying DOVE token to testnet
 * Focus is on successful deployment and verification, without additional testing
 *
 * Run with: `pnpm hardhat run scripts/test-deployment.ts --network baseSepolia`
 */
async function main() {
  try {
    console.log('=== DOVE Token Testnet Deployment ===');

    // Get signers
    const [deployer] = await ethers.getSigners();
    console.log(`Using deployer address: ${deployer.address}`);

    // Get charity wallet from env or use deployer as fallback
    const charityWallet = process.env.TESTNET_CHARITY_WALLET || deployer.address;
    console.log(`Using charity wallet: ${charityWallet}`);

    // Deploy token
    console.log('\n1. Deploying DOVE token...');
    const deployment = await deployDove();
    const { dove, adminManager } = deployment;
    const doveAddress = await dove.getAddress();
    const adminAddress = await adminManager.getAddress();

    console.log(`Deployment completed successfully:`);
    console.log(`- DOVE token: ${doveAddress}`);
    console.log(`- DOVEAdmin: ${adminAddress}`);

    // Verify the token is configured correctly
    console.log('\n2. Checking token configuration...');

    // FeeManager is now internal to DOVE; pull info via public view functions
    const charityFee = await dove.CHARITY_FEE_BP();
    console.log(`Charity fee: ${charityFee.toString()} basis points (${Number(charityFee) / 100}%)`);

    console.log('\n=== Deployment Complete ===');
    console.log(`Contract addresses:`);
    console.log(`- DOVE token: ${doveAddress}`);
    console.log(`- Admin Manager: ${adminAddress}`);
    console.log('\nDeployment to Base Sepolia testnet was successful!');
    console.log('To interact with these contracts, use the Hardhat console or front-end application.');

    console.log('\nManually verify contracts if needed with:');
    console.log(`npx hardhat verify --network baseSepolia ${doveAddress} "${charityWallet}"`);
  } catch (error) {
    console.error('\n❌ Deployment failed:');
    console.error(error);
    process.exit(1);
  }
}

// Auto-execute if script is run directly
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
