import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractFactory } from 'ethers';

/**
 * Utility module for contract verification on BaseScan
 * @module verify
 */

/**
 * Verifies a contract on BaseScan
 * 
 * @param {HardhatRuntimeEnvironment} hre - Hardhat Runtime Environment
 * @param {string} contractAddress - Address of the deployed contract
 * @param {any[]} constructorArguments - Constructor arguments used during deployment
 */
export async function verifyContract(
  hre: HardhatRuntimeEnvironment,
  contractAddress: string,
  constructorArguments: any[] = []
): Promise<void> {
  console.log(`\nVerifying contract at ${contractAddress}`);

  try {
    await hre.run('verify:verify', {
      address: contractAddress,
      constructorArguments,
    });
    console.log('✅ Contract verification successful');
  } catch (error: any) {
    if (error.message.includes('already verified')) {
      console.log('⚠️ Contract already verified');
    } else {
      console.error('❌ Error during verification:', error);
      throw error;
    }
  }
}

/**
 * Deploys and verifies a contract in one step
 * 
 * @param {HardhatRuntimeEnvironment} hre - Hardhat Runtime Environment
 * @param {ContractFactory} factory - Contract factory
 * @param {any[]} args - Constructor arguments
 * @returns {Promise<string>} Deployed contract address
 */
export async function deployAndVerify(
  hre: HardhatRuntimeEnvironment,
  factory: ContractFactory,
  args: any[] = []
): Promise<string> {
  console.log(`\nDeploying ${factory.constructor.name}...`);
  
  const contract = await factory.deploy(...args);
  await contract.waitForDeployment();
  
  const address = await contract.getAddress();
  console.log(`${factory.constructor.name} deployed to:`, address);
  
  // Wait for a few blocks to ensure the contract is indexed
  console.log('Waiting for contract to be indexed...');
  await new Promise(resolve => setTimeout(resolve, 20000)); // 20 second delay
  
  await verifyContract(hre, address, args);
  
  return address;
}
