import { ethers } from 'hardhat';
// import { verify } from '../utils/verify'; // optional verification helper

/**
 * Deploy DOVE token contract to the Base Sepolia testnet
 * Usage: `pnpm hardhat run scripts/deploy/dove.ts --network baseSepolia`
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

  // Step 1: Deploy DOVEAdmin contract (owns roles & timelock)
  console.log('Deploying DOVEAdmin contract...');
  const DOVEAdminFactory = await ethers.getContractFactory('DOVEAdmin');
  const adminManager = await DOVEAdminFactory.deploy(multisigAddress);
  const adminAddress = await adminManager.getAddress();
  console.log(`DOVEAdmin deployed at: ${adminAddress}`);

  // Step 2: Deploy DOVE token contract with admin + charity wallet params
  console.log('Deploying DOVE token contract...');
  const DOVEFactory = await ethers.getContractFactory('DOVE');
  const dove = await DOVEFactory.deploy(adminAddress, charityWallet, multisigAddress);
  const doveAddress = await dove.getAddress();
  console.log(`DOVE token deployed at: ${doveAddress}`);

  // Verify contracts on block explorer if not on a local network
  const { chainId } = await ethers.provider.getNetwork();
  if (chainId !== 31337n) {
    // Not localhost
    console.log('Waiting for block confirmations...');

    // Wait for confirmations for each contract
    const adminTx = adminManager.deploymentTransaction();
    if (adminTx) await adminTx.wait(6);

    const doveTx = dove.deploymentTransaction();
    if (doveTx) await doveTx.wait(6);

    // Optionally verify contracts here
    // console.log('Verifying contracts on BaseScan...');

    // try {
    //   // Verify DOVEAdmin contract
    //   await verify(adminAddress, [multisigAddress]);
    //   console.log('DOVEAdmin contract verified on BaseScan');

    //   // Verify the main token contract
    //   await verify(doveAddress, [adminAddress, charityWallet, multisigAddress]);
    //   console.log('DOVE contract verified on BaseScan');
    // } catch (error) {
    //   console.log('Warning: Contract verification failed. You may need to verify them manually.');
    //   console.error(error);
    // }
  }

  // Print ownership transfer instructions
  if (deployer.address !== multisigAddress) {
    console.log(`\nIMPORTANT: Transfer ownership to multisig (${multisigAddress}) using these commands:`);
    console.log(`\n1. For DOVEAdmin (${adminAddress}):`);
    console.log(
      `   npx hardhat --network baseSepolia run scripts/admin/transfer-ownership.js --contract ${adminAddress} --new-owner ${multisigAddress}`
    );

    console.log(`\n2. For DOVE token (${doveAddress}):`);
    console.log(
      `   npx hardhat --network baseSepolia run scripts/admin/grant-role.js --contract ${doveAddress} --role DEFAULT_ADMIN_ROLE --account ${multisigAddress}`
    );
    console.log(
      `   npx hardhat --network baseSepolia run scripts/admin/revoke-role.js --contract ${doveAddress} --role DEFAULT_ADMIN_ROLE --account ${deployer.address}`
    );
  }

  return { dove, adminManager };
}

// Auto-execute if script is run directly
if (require.main === module) {
  deployDove()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
