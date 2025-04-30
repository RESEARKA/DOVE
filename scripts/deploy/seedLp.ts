import { ethers } from "hardhat";
import { DOVE } from "../../typechain-types";

/**
 * Seeds initial liquidity pool with 10B DOVE + 1.67 ETH as specified in DOVE Developer Guidelines
 * Usage: `pnpm hardhat run scripts/deploy/seedLp.ts --network base`
 * 
 * Should be run after the main deployment script (dove.ts)
 * Requires DOVE contract address in environment variable DOVE_ADDRESS
 */
async function seedLiquidity() {
  const [deployer] = await ethers.getSigners();
  console.log(`Seeding LP with the account: ${deployer.address}`);
  
  // Load deployed DOVE contract
  const doveAddress = process.env.DOVE_ADDRESS;
  if (!doveAddress) {
    throw new Error("DOVE_ADDRESS environment variable is required");
  }
  
  // Set ETH amount for liquidity
  const ethAmount = ethers.utils.parseEther("1.67"); // 1.67 ETH as specified in guidelines
  
  // Set DOVE amount for liquidity (10 billion)
  const doveAmount = ethers.utils.parseEther("10000000000"); // 10B DOVE
  
  // Connect to DOVE contract
  const dove = (await ethers.getContractAt("DOVE", doveAddress)) as DOVE;
  
  // Get router address from environment
  const routerAddress = process.env.DEX_ROUTER_ADDRESS;
  if (!routerAddress) {
    throw new Error("DEX_ROUTER_ADDRESS environment variable is required");
  }
  
  // Get the current allowance
  const currentAllowance = await dove.allowance(deployer.address, routerAddress);
  
  // Approve router to spend tokens if not already approved
  if (currentAllowance.lt(doveAmount)) {
    console.log(`Approving DEX Router to spend ${ethers.utils.formatEther(doveAmount)} DOVE...`);
    const approveTx = await dove.approve(routerAddress, doveAmount);
    await approveTx.wait();
    console.log("Approval confirmed");
  } else {
    console.log("Router already has sufficient allowance");
  }
  
  // Create pair and add liquidity (this requires interacting with the router contract)
  const router = await ethers.getContractAt("IUniswapV2Router02", routerAddress);
  
  console.log(`Adding liquidity: ${ethers.utils.formatEther(doveAmount)} DOVE + ${ethers.utils.formatEther(ethAmount)} ETH`);
  
  // Add liquidity with minimum amounts set to 99% to account for minor price fluctuations
  const tx = await router.addLiquidityETH(
    doveAddress,                                    // token address
    doveAmount,                                     // token amount
    doveAmount.mul(99).div(100),                    // min token amount (99%)
    ethAmount.mul(99).div(100),                     // min ETH amount (99%)
    deployer.address,                               // LP tokens recipient
    Math.floor(Date.now() / 1000) + 60 * 20,        // deadline: 20 minutes
    { value: ethAmount }                            // ETH value
  );
  
  const receipt = await tx.wait();
  console.log(`Liquidity added successfully in tx: ${receipt.transactionHash}`);
  
  // Mark the DEX as known in the DOVE contract
  const factory = await ethers.getContractAt("IUniswapV2Factory", await router.factory());
  const pairAddress = await factory.getPair(doveAddress, await router.WETH());
  
  console.log(`LP pair created at: ${pairAddress}`);
  
  // Set pair address as known DEX
  if (pairAddress !== ethers.constants.AddressZero) {
    console.log("Setting LP pair as known DEX for early-sell tax detection...");
    const setDexTx = await dove.setDexStatus(pairAddress, true);
    await setDexTx.wait();
    console.log("LP pair set as known DEX");
    
    // Also mark router as DEX
    const setRouterTx = await dove.setDexStatus(routerAddress, true);
    await setRouterTx.wait();
    console.log("Router set as known DEX");
  }
  
  return { pairAddress, doveAmount, ethAmount };
}

// Auto-execute if script is run directly
if (require.main === module) {
  seedLiquidity()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
}
