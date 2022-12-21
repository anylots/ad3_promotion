

// This is a script for deploying your contracts. You can adapt it to deploy
// yours, or create new ones.
async function main() {
    // await transferOwner();
    const [deployer] = await ethers.getSigners();

    console.log(
        "Deploying contracts with the account:",
        await deployer.getAddress()
    );

    let customHttpProvider = new ethers.providers.JsonRpcProvider("http://8.210.2.244:9933");

    console.log("\n1. query moonbeam chain id & name")
    const network = await customHttpProvider.getNetwork();
    console.log(network);


    console.log("\n2. query block height")
    const blockNumber = await customHttpProvider.getBlockNumber();
    console.log(blockNumber);

    console.log("\n4. query current gas price")
    const gasPrice = await customHttpProvider.getGasPrice();
    console.log(gasPrice);

    console.log("\n5. query gas data current recomend")
    const feeData = await customHttpProvider.getFeeData();
    console.log(feeData);

    console.log("\n6. query blcok data")
    const block = await customHttpProvider.getBlock(1);
    console.log(block);

    console.log("\n7. query contract bytecode")
    const code = await customHttpProvider.getCode("0xc778417e063141139fce010982780140aa0cd5ab");
    console.log(code);

}

//npx hardhat --network moonbeamdev run  .\scripts\moonbeamdev.js
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });