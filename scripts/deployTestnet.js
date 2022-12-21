const usdt_address = '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9';


// This is a script for deploying your contracts. You can adapt it to deploy
// yours, or create new ones.
async function main() {

  // await transferOwner();
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    await deployer.getAddress()
  );
  
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const AD3Hub = await ethers.getContractFactory("AD3Hub");
  const ad3Hub = await AD3Hub.deploy();
  await ad3Hub.deployed();
  console.log("ad3Hub address:", ad3Hub.address);

  const USDT = await ethers.getContractFactory("TetherToken");
  const token = await USDT.deploy(10 ** 12); //totalSupply = $10 ** 6
  await token.deployed();
  console.log("token address:", token.address);

  const Campaign = await ethers.getContractFactory("Campaign");
  const campaign = await Campaign.deploy();
  await campaign.deployed();
  console.log("campaignImpl address:", campaign.address);

  await ad3Hub.setCampaignImpl(campaign.address);

  await ad3Hub.setPaymentToken(token.address);
  
  await ad3Hub.setTrustedSigner(deployer.address);

}

// async function transferOwner(){
//   //e68b7e564ec7760869134a7e45e04afb8e3cc790b0771de34b4cf306190a2ccf
//   const [signer] = await ethers.getSigners();
//   const AD3Hub_Artifact = require("../artifacts/contracts/AD3Hub.sol/AD3Hub.json")
//   let ad3Hub = new ethers.Contract(
//       '0xc1A83b13e858909ac089180D34304259EC3F71Eb',
//       AD3Hub_Artifact.abi,
//       signer
//   );
//   await ad3Hub.transferOwnership("0xa6b0110b3e371Cc79D7aE37D9cC5D26818Fa18C5");


// }



main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
