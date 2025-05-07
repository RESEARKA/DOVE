// Exclude allocation wallets from max wallet limit
// Usage: npx hardhat run scripts/admin/exclude-wallets-from-limit.js --network base

const { ethers } = require("hardhat");

async function main() {
  // Contract addresses
  const tokenAddress = "0x7be8982c3f67B136a695874dF4536E603e8023a6"; // DOVE token address
  
  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log(`Using account: ${deployer.address}`);
  
  // Get token contract (DOVE has direct function for excluding wallets)
  const dove = await ethers.getContractAt("DOVE", tokenAddress);
  
  // Define allocation wallets to exclude from max wallet limit
  const wallets = [
    {
      name: "Founder/Team",
      address: "0x20a43d9D1969206E9778D890a3191361903252c0" 
    },
    {
      name: "Liquidity Provision",
      address: "0xd02AC8129309a9c24392d04Bf06d827eC25888Fe" 
    },
    {
      name: "Community & Airdrops",
      address: "0x083CA3260DA3018DF4EAFe910F45445ABF2c7897" 
    },
    {
      name: "Ecosystem Development Fund",
      address: "0x35C8D89F79faee563B2ff272d66195016d6fdFc0" 
    },
    {
      name: "Marketing & Partnerships",
      address: "0xD268D34DC023Bcb3C2300B60494A75b3a4022997" 
    },
    {
      name: "CEX-Listing Reserve",
      address: "0x6Bb8d0a50D03B26F59037b0C18837018Af2af58E" 
    },
    {
      name: "Bug-Bounty & Security",
      address: "0x88892C8d9E07c4c2F812356ce012e2ED585be5D7" 
    },
    {
      name: "Treasury/Ops Buffer",
      address: "0xa689eaD23b671CAbF0E79cc59E0C8a6B937d5309" 
    },
    {
      name: "Charity Pool",
      address: "0xb29984ef12F790B8908Bc1Ca17a9eD9238Aa46f7" 
    },
    {
      name: "Referral/Promo Pool",
      address: "0x409b2254E9B09b162Db2f0b5621A0D06466B5C97" 
    }
  ];
  
  // Process each wallet
  for (const wallet of wallets) {
    console.log(`\nProcessing ${wallet.name} wallet (${wallet.address})...`);
    
    try {
      console.log(`Setting ${wallet.name} wallet to be excluded from max wallet limit...`);
      const tx = await dove.setExcludedFromMaxWalletLimit(wallet.address, true, {
        gasLimit: 300000
      });
      console.log(`Transaction hash: ${tx.hash}`);
      await tx.wait();
      console.log(`✅ ${wallet.name} wallet successfully excluded from max wallet limit!`);
    } catch (error) {
      console.error(`Error processing ${wallet.name} wallet:`, error.message);
    }
  }
  
  console.log("\nAll wallet exclusions processed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
