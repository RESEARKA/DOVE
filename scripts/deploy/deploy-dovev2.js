// Deploy DOVEv2 Token with pre-allocated supply distribution
// This script deploys the improved DOVE token with direct wallet allocations
// Usage: npx hardhat run scripts/deploy/deploy-dovev2.js --network base

const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("\n==== DOVE Token v2 Deployment Process ====\n");
  
  // Get deployer account
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with account: ${deployer.address}`);
  
  // Print deployer balance
  const balance = await deployer.getBalance();
  console.log(`Account balance: ${ethers.utils.formatEther(balance)} ETH`);
  
  // Configuration - CRITICAL ADDRESSES - VERIFY THESE ARE CORRECT
  const CHARITY_WALLET = "0xb29984ef12F790B8908Bc1Ca17a9eD9238Aa46f7";
  
  console.log("\n==== Step 1: Deploy DOVEAdmin Contract ====");
  
  // Deploy Admin contract first
  const DOVEAdmin = await ethers.getContractFactory("DOVEAdmin");
  console.log("Deploying DOVEAdmin contract...");
  const admin = await DOVEAdmin.deploy();
  await admin.deployed();
  console.log(`DOVEAdmin deployed to: ${admin.address}`);
  
  // Confirmation step
  console.log("\nVerify these details before proceeding:");
  console.log(`1. DOVEAdmin Contract: ${admin.address}`);
  console.log(`2. Charity Wallet: ${CHARITY_WALLET}`);
  
  const readline = require('readline').createInterface({
    input: process.stdin,
    output: process.stdout
  });
  
  const confirmDeploy = await new Promise(resolve => {
    readline.question('\nDo you want to continue with DOVEv2 deployment? (yes/no): ', answer => {
      resolve(answer.toLowerCase() === 'yes');
      readline.close();
    });
  });
  
  if (!confirmDeploy) {
    console.log("Deployment cancelled by user.");
    return;
  }
  
  console.log("\n==== Step 2: Deploy DOVEv2 Token ====");
  
  // Deploy the DOVEv2 token with built-in allocations
  const DOVEv2 = await ethers.getContractFactory("DOVEv2");
  console.log("Deploying DOVEv2 token with pre-allocated distribution...");
  const dove = await DOVEv2.deploy(admin.address, CHARITY_WALLET);
  await dove.deployed();
  console.log(`DOVEv2 token deployed to: ${dove.address}`);
  
  console.log("\n==== Step 3: Deploy DOVEGovernance Contract ====");
  
  // Deploy Governance contract
  const DOVEGovernance = await ethers.getContractFactory("DOVEGovernance");
  console.log("Deploying DOVEGovernance contract...");
  const governance = await DOVEGovernance.deploy(admin.address);
  await governance.deployed();
  console.log(`DOVEGovernance deployed to: ${governance.address}`);
  
  console.log("\n==== Step 4: Deploy DOVEInfo Contract ====");
  
  // Deploy Info contract
  const DOVEInfo = await ethers.getContractFactory("DOVEInfo");
  console.log("Deploying DOVEInfo contract...");
  const info = await DOVEInfo.deploy();
  await info.deployed();
  console.log(`DOVEInfo deployed to: ${info.address}`);
  
  console.log("\n==== Step 5: Initialize Secondary Contracts ====");
  
  // Initialize Info contract
  console.log("Initializing DOVEInfo contract...");
  const maxTxAmount = ethers.utils.parseUnits("1000000000", 18); // 1B DOVE max tx
  await info.initialize(
    dove.address,
    await dove.getFeeManager(),
    governance.address,
    maxTxAmount
  );
  console.log("DOVEInfo contract initialized successfully");
  
  // Set secondary contracts in DOVE token
  console.log("Setting secondary contracts in DOVEv2 token...");
  const setSecondaryTx = await dove.setSecondaryContracts(info.address);
  await setSecondaryTx.wait();
  console.log("Secondary contracts set in DOVEv2 token");
  
  // Set DOVE token in Admin contract
  console.log("Setting DOVEv2 token in Admin contract...");
  const setTokenTx = await admin.setToken(dove.address);
  await setTokenTx.wait();
  console.log("DOVEv2 token set in Admin contract");
  
  console.log("\n==== Step 6: Launch Token ====");
  
  // Launch token (unpause)
  console.log("Launching DOVEv2 token (unpausing)...");
  const launchTx = await dove.launch();
  await launchTx.wait();
  console.log("✅ DOVEv2 token launched successfully!");
  
  console.log("\n==== Step 7: Save Deployment Details ====");
  
  // Save deployment details to file
  const deploymentDetails = {
    network: network.name,
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      DOVEv2: dove.address,
      DOVEAdmin: admin.address,
      DOVEGovernance: governance.address,
      DOVEInfo: info.address,
      DOVEFees: await dove.getFeeManager()
    },
    configuration: {
      charityWallet: CHARITY_WALLET,
      maxTransactionAmount: maxTxAmount.toString()
    }
  };
  
  const deploymentPath = path.join(__dirname, '../../', 'deployment-v2.json');
  fs.writeFileSync(
    deploymentPath,
    JSON.stringify(deploymentDetails, null, 2)
  );
  console.log(`Deployment details saved to ${deploymentPath}`);
  
  console.log("\n==== Allocation Summary ====");
  console.log("Token distribution has been pre-allocated to:");
  
  const allocationWallets = [
    { name: "Founder/Team (7.5%)", address: "0x20a43d9D1969206E9778D890a3191361903252c0" },
    { name: "Liquidity Provision (38%)", address: "0xd02AC8129309a9c24392d04Bf06d827eC25888Fe" },
    { name: "Community & Airdrops (16%)", address: "0x083CA3260DA3018DF4EAFe910F45445ABF2c7897" },
    { name: "Ecosystem Development (10%)", address: "0x35C8D89F79faee563B2ff272d66195016d6fdFc0" },
    { name: "Marketing & Partnerships (7.5%)", address: "0xD268D34DC023Bcb3C2300B60494A75b3a4022997" },
    { name: "CEX-Listing Reserve (5%)", address: "0x6Bb8d0a50D03B26F59037b0C18837018Af2af58E" },
    { name: "Bug-Bounty & Security (2.5%)", address: "0x88892C8d9E07c4c2F812356ce012e2ED585be5D7" },
    { name: "Treasury/Ops Buffer (3.5%)", address: "0xa689eaD23b671CAbF0E79cc59E0C8a6B937d5309" },
    { name: "Charity Pool (2%)", address: "0xb29984ef12F790B8908Bc1Ca17a9eD9238Aa46f7" },
    { name: "Referral/Promo Pool (1%)", address: "0x409b2254E9B09b162Db2f0b5621A0D06466B5C97" }
  ];
  
  for (const wallet of allocationWallets) {
    console.log(`${wallet.name}: ${wallet.address}`);
  }
  
  console.log("\n==== Next Steps ====");
  console.log("1. Verify all contracts on BaseScan");
  console.log("2. Transfer DOVEAdmin ownership to multisig (if needed)");
  console.log("3. Set up liquidity providing on DEX");
  
  console.log("\n==== DOVEv2 Deployment Complete ====");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
