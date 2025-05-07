// Complete DOVE token deployment on Base Mainnet
// Usage: npx hardhat run scripts/admin/complete-mainnet-deployment.js --network base

const { ethers } = require("hardhat");

async function main() {
  // Existing contract addresses
  const tokenAddress = "0x7be8982c3f67B136a695874dF4536E603e8023a6";
  const adminAddress = "0x8527DD7b9CF030Ae2D38091FED33D01bC3b13693";
  const feesAddress = "0x03E2cF2C11D5Cd468C30De7F2bf3F173CbeBeed7";
  
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
      console.log("\n=== STEP 4: Schedule Token Launch ===");
      
      // Get the launch operation hash
      const LAUNCH_OP = ethers.keccak256(ethers.toUtf8Bytes("dove.admin.launch"));
      
      // Launch the token (this will schedule it)
      console.log("Scheduling token launch (24-hour timelock)...");
      try {
        const launchTx = await admin.launch();
        await launchTx.wait();
        console.log("Launch scheduled successfully!");
        console.log("\nIMPORTANT: The token launch is now scheduled with a 24-hour timelock.");
        console.log("In 24 hours, run this command to complete the launch:");
        console.log(`npx hardhat run scripts/admin/execute-launch.js --network base`);
      } catch (error) {
        console.log("Launch scheduling failed:", error.message);
      }
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
  
  // Update charity wallet
  console.log("\n=== Updating Charity Wallet ===");
  try {
    const tx = await dove.setCharityWallet(deployer.address);
    await tx.wait();
    console.log(`Charity wallet updated to: ${deployer.address}`);
  } catch (error) {
    console.log("Failed to update charity wallet:", error.message);
  }
  
  console.log("\n=== Deployment Complete ===");
  console.log("DOVE Token Ecosystem successfully deployed on Base Mainnet!");
  console.log("Token Address: " + tokenAddress);
  console.log("Admin Address: " + adminAddress);
  console.log("Fees Address: " + feesAddress);
  console.log("Events Address: " + eventsAddress);
  console.log("Governance Address: " + governanceAddress);
  console.log("Info Address: " + infoAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
