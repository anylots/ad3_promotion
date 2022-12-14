
const Campaign_Artifact = require("../artifacts/contracts/Campaign.sol/Campaign.json")
const USDT_Artifact = require("../artifacts/contracts/Token.sol/TetherToken.json")
const fs = require('fs');


async function main() {

    await claimPrize();
}

async function claimPrize() {
    let campaignAddress = '0x94099942864EA81cCF197E9D71ac53310b1468D8';
    let usdtAddress = '0x8A791620dd6260079BF849Dc5567aDC3F2FdC318';

    let privateKey = "0xde9be858da4a475276426320d5e9262ecfc3ba460bfac56360bfa6c4c28b4ee0";
    let customHttpProvider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545");
    const signer = new ethers.Wallet(privateKey, customHttpProvider);

    let Campaign = new ethers.Contract(
        campaignAddress,
        Campaign_Artifact.abi,
        signer
    );

    let USDT = new ethers.Contract(
        usdtAddress,
        USDT_Artifact.abi,
        signer
    );

    let balance = await USDT.balanceOf(signer.address);
    console.log("balance before claim:" + balance);

    let result = await Campaign.claimUserPrize(fetchCoupon(signer.address), 10);
    let info = await customHttpProvider.getTransactionReceipt(result.hash);
    console.log("claimUserPrize gas used:" + info.gasUsed);

    balance = await USDT.balanceOf(signer.getAddress());
    console.log("balance after claim:" + balance);

}

function fetchCoupon(address) {
    // retrieve the wallet from the query wallet
    // const wallet = req.query.wallet

    // Find a coupon for the passed wallet address

    let data = fs.readFileSync('./resource/coupons.json');
    // console.log("readFileSync: " + data.toString());
    let coupons = JSON.parse(data);

    const c = coupons.filter(coupon => coupon.wallet.toLowerCase() === address.toLowerCase())
    if (c !== undefined) {
        return c[0];
    } else {
        throw "can not find coupon";
    }
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });


