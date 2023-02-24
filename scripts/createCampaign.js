const usdt_address = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512';
const Token_Artifact = require("../artifacts/contracts/Token.sol/TetherToken.json")
const Campaign_Artifact = require("../artifacts/contracts/Campaign.sol/Campaign.json")
const AD3Hub_Artifact = require("../artifacts/contracts/AD3Hub.sol/AD3Hub.json")
const ad3hub_address = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

const overrides = {
    gasLimit: 15000000,
    gasPrice: 10 * (10 ** 9)
}

// This is a script for deploying your contracts. You can adapt it to deploy
// yours, or create new ones.
async function main() {
    const [deployer] = await ethers.getSigners();

    console.log(
        "Deploying contracts with the account:",
        await deployer.getAddress()
    );

    console.log("Account balance:", (await deployer.getBalance()).toString());

    let token = new ethers.Contract(
        usdt_address,
        Token_Artifact.abi,
        deployer
    );
    await token.approve(ad3hub_address, 20000000);


    let AD3Hub = new ethers.Contract(
        ad3hub_address,
        AD3Hub_Artifact.abi,
        deployer
    );
    let createCampaign = await AD3Hub.createCampaign(10000000, 10000000, usdt_address, usdt_address, overrides);
    console.log("createCampaign:" + createCampaign.hash);
    let campaignAddress = await AD3Hub.getCampaignAddress(deployer.address, 1);
    console.log('campaignAddress: ' + campaignAddress);






}




main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
