// Complete DOVE token deployment on Base Sepolia testnet
// Usage: npx hardhat run scripts/admin/complete-deployment.js --network baseSepolia

const { ethers } = require("hardhat");

async function main() {
  // Existing contract addresses
  const tokenAddress = "0x272aaD940552f67C3cC763734AdA53f1A4bA3375";
  const adminAddress = "0xA4732CdB0916B6B4a04d32d20CB72eE53858C745";
  const feesAddress = "0x383223Adf3ae6EC2BeD1E9Fa4fcfc42434820827";
  
  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);
  
  // Get existing contract instances
  const dove = await ethers.getContractAt("DOVE", tokenAddress);
  const admin = await ethers.getContractAt("DOVEAdmin", adminAddress);
  const feeManager = await ethers.getContractAt("DOVEFees", feesAddress);
  
  console.log("\n=== STEP 1: Deploy Auxiliary Contracts ===");
  
  // Deploy DOVEEvents
  console.log("Deploying DOVEEvents...");
  const DOVEEventsFactory = await ethers.getContractFactory("DOVEEvents");
  const eventsContract = await DOVEEventsFactory.deploy();
  await eventsContract.deploymentTransaction().wait(1);
  const eventsAddress = await eventsContract.getAddress();
  console.log(`DOVEEvents deployed at: ${eventsAddress}`);
  
  // Deploy DOVEGovernance
  console.log("\nDeploying DOVEGovernance...");
  const DOVEGovernanceFactory = await ethers.getContractFactory("DOVEGovernance");
  const governanceContract = await DOVEGovernanceFactory.deploy();
  await governanceContract.deploymentTransaction().wait(1);
  const governanceAddress = await governanceContract.getAddress();
  console.log(`DOVEGovernance deployed at: ${governanceAddress}`);
  
  // Deploy DOVEInfo
  console.log("\nDeploying DOVEInfo...");
  const DOVEInfoFactory = await ethers.getContractFactory("DOVEInfo");
  const infoContract = await DOVEInfoFactory.deploy();
  await infoContract.deploymentTransaction().wait(1);
  const infoAddress = await infoContract.getAddress();
  console.log(`DOVEInfo deployed at: ${infoAddress}`);
  
  console.log("\n=== STEP 2: Initialize Auxiliary Contracts ===");
  
  // Initialize DOVEEvents
  console.log("Initializing DOVEEvents...");
  try {
    const initEventsTx = await eventsContract.initialize(tokenAddress);
    await initEventsTx.wait();
    console.log("DOVEEvents initialized.");
  } catch (error) {
    console.log("DOVEEvents initialization failed:", error.message);
  }
  
  // Initialize DOVEGovernance
  console.log("\nInitializing DOVEGovernance...");
  try {
    const initGovTx = await governanceContract.initialize(adminAddress);
    await initGovTx.wait();
    console.log("DOVEGovernance initialized.");
  } catch (error) {
    console.log("DOVEGovernance initialization failed:", error.message);
  }
  
  // Initialize DOVEInfo
  console.log("\nInitializing DOVEInfo...");
  try {
    const maxTxAmount = ethers.parseEther("1000000000"); // 1 billion token limit (1% of supply)
    const initInfoTx = await infoContract.initialize(
      tokenAddress,
      feesAddress,
      governanceAddress,
      maxTxAmount
    );
    await initInfoTx.wait();
    console.log("DOVEInfo initialized.");
  } catch (error) {
    console.log("DOVEInfo initialization failed:", error.message);
  }
  
  console.log("\n=== STEP 3: Initialize DOVE Token with Auxiliary Contracts ===");
  
  try {
    console.log("Calling initialiseTokenContracts on DOVEAdmin...");
    const initTokenTx = await admin.initialiseTokenContracts(
      eventsAddress,
      governanceAddress,
      infoAddress
    );
    await initTokenTx.wait();
    
    // Check if token is fully initialized
    const fullyInitialized = await dove.isFullyInitialized();
    console.log(`Token fully initialized: ${fullyInitialized}`);
    
    if (fullyInitialized) {
      console.log("\n=== STEP 4: Launch Token (Bypass Timelock) ===");
      
      // Get the launch operation hash
      const LAUNCH_OP = ethers.keccak256(ethers.toUtf8Bytes("dove.admin.launch"));
      
      // Bypass timelock for testing
      console.log("Bypassing timelock...");
      try {
        const bypassTx = await admin.TEST_setOperationTimelockElapsed(LAUNCH_OP);
        await bypassTx.wait();
        console.log("Timelock bypassed.");
      } catch (error) {
        console.log("Timelock bypass failed:", error.message);
      }
      
      // Launch the token
      console.log("Launching token...");
      try {
        const launchTx = await admin.launch();
        await launchTx.wait();
        console.log("Token launched successfully!");
      } catch (error) {
        console.log("Launch failed:", error.message);
      }
      
      // Check if token is unpaused
      const isPaused = await dove.paused();
      console.log(`\nToken is ${isPaused ? 'still paused' : 'now active for transfers'}`);
    }
  } catch (error) {
    console.log("Error initializing token:", error.message);
  }
  
  // Final status
  console.log("\n=== Final Token Status ===");
  const name = await dove.name();
  const symbol = await dove.symbol();
  const totalSupply = await dove.totalSupply();
  const formattedSupply = ethers.formatEther(totalSupply);
  const isPaused = await dove.paused();
  
  console.log(`Name: ${name}`);
  console.log(`Symbol: ${symbol}`);
  console.log(`Total Supply: ${formattedSupply} DOVE`);
  console.log(`Token Paused: ${isPaused}`);
  console.log(`\nYou can now ${isPaused ? 'check' : 'use'} your DOVE tokens on Base Sepolia testnet!`);
  console.log(`Token Address: ${tokenAddress}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
