const Campaign_Artifact = require("../artifacts/contracts/Campaign.sol/Campaign.json");
const USDT_Artifact = require("../artifacts/contracts/Token.sol/TetherToken.json");
const fs = require("fs");
const { ethers } = require("ethers");

const overrides = {
  gasLimit: 15000000,
  gasPrice: 10 * 10 ** 9,
};

async function main() {
  await claimPrize();
}

async function claimPrize() {
  let campaignAddress = "0xa16E02E87b7454126E5E10d957A927A7F5B5d2be";
  let usdtAddress = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";

  //todo server
  if (ethers.utils.isAddress(usdtAddress) === false) {
    console.log("Not an eth address");
    return;
  }

  let privateKey =
    "0xde9be858da4a475276426320d5e9262ecfc3ba460bfac56360bfa6c4c28b4ee0";
  let customHttpProvider = new ethers.providers.JsonRpcProvider(
    "http://127.0.0.1:8545"
  );
  const signer = new ethers.Wallet(privateKey, customHttpProvider);
  console.log(signer.address);

  let Campaign = new ethers.Contract(
    campaignAddress,
    Campaign_Artifact.abi,
    signer
  );

  let USDT = new ethers.Contract(usdtAddress, USDT_Artifact.abi, signer);

  console.log("signer.address:" + signer.address);

  let balance = await USDT.balanceOf(signer.address);
  console.log("balance before claim:" + balance);

  let result = await Campaign.claimCpaReward(
    10,
    fetchCoupon(signer.address).signature,
    overrides
  );
  let info = await customHttpProvider.getTransactionReceipt(result.hash);
  console.log("claimCpaReward gas used:" + info.gasUsed);

  balance = await USDT.balanceOf(signer.getAddress());
  console.log("balance after claim:" + balance);
}

function fetchCoupon(address) {
  // retrieve the wallet from the query wallet
  // const wallet = req.query.wallet

  // Find a coupon for the passed wallet address

  let data = fs.readFileSync("./resource/coupons.json");
  // console.log("readFileSync: " + data.toString());
  let coupons = JSON.parse(data);

  const c = coupons.filter(
    (coupon) => coupon.wallet.toLowerCase() === address.toLowerCase()
  );
  if (c !== undefined) {
    // console.log(c[0]);
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
