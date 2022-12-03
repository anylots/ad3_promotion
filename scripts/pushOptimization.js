
const Campaign_Artifact = require("../artifacts/contracts/Campaign.sol/Campaign.json")

const overrides = {
    gasLimit: 15000000,
    gasPrice: 10 * (10 ** 9)
}

async function main() {

    // await transferUSDT();
    await pushPay();

}

async function pushPay() {
    // Connect a wallet to localhost
    let customHttpProvider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545");

    let campaignImpl = await deployCampaignImpl();
    console.log("campaignImpl: "+ campaignImpl);

    const { ad3Hub, owner } = await deployAD3HubFixture();
    console.log(owner.address);

    const { token } = await deployPaymentToken();
    console.log("usdtAddress: "+ token.address);

    await ad3Hub.setCampaignImpl(campaignImpl);
    await ad3Hub.setPaymentToken(token.address);
    await ad3Hub.setTrustedSigner(owner.address);

    //1000 usdt
    //https://ethereum.org/en/developers/tutorials/send-token-etherjs/
    let numberOfTokens = ethers.utils.parseUnits("1000", 2);
    console.log("numberOfTokens:" + numberOfTokens);
    await token.approve(ad3Hub.address, numberOfTokens);

    let kols = await getKolsFixtrue();
    console.log("startCreateCampaign:" + kols.length);

    let createCampaign = await ad3Hub.createCampaign(kols, 100000, 12);
    let receipt = await customHttpProvider.getTransactionReceipt(createCampaign.hash);
    console.log("createCampaign gas used:" + receipt.gasUsed);

    let campaignAddress = await ad3Hub.getCampaignAddress(owner.address, 1);
    console.log('campaignAddress: ' + campaignAddress);
    let Campaign = new ethers.Contract(
        campaignAddress,
        Campaign_Artifact.abi,
        owner
    );
    let resultBeforePay = await Campaign.remainBalance();
    console.log("resultBeforePay:" + resultBeforePay);
    // campaign amount
    let numberOfAmount = ethers.utils.formatUnits(resultBeforePay, 2);
    console.log("numberOfAmount:" + numberOfAmount);


    let kolAddress = await getKolsAddress();
    //first kol pay
    payfixFee = await ad3Hub.payfixFee(kolAddress, owner.address, 1);
    receipt = await customHttpProvider.getTransactionReceipt(payfixFee.hash);
    console.log("payfixFee gas used:" + receipt.gasUsed);


    //second kol pay
    await ad3Hub.payfixFee(kolAddress, owner.address, 1);


    //UserPay and check campaign's balance
    let kolWithUsers = await getKolWithUsers();

    console.log("starting pushPay");

    // let result = await Campaign.pushPay(kolWithUsers);
    // let result = await ad3Hub.pushPayTest(owner.address, 1, kolWithUsers, overrides);

    let result = await ad3Hub.pushPay(owner.address, 1, kolWithUsers, overrides);
    console.log("finish pushPay");
    let info = await customHttpProvider.getTransactionReceipt(result.hash);
    console.log("pushPay gas used:" + info.gasUsed);

    let kolWithQuantity = await getKolWithUserQuantity();
    result = await ad3Hub.pushPayKol(owner.address, 1, kolWithQuantity, overrides);
    console.log("finish pushPayKol");

    info = await customHttpProvider.getTransactionReceipt(result.hash);
    console.log("pushPayKol gas used:" + info.gasUsed);

    let resultAfterUserPay = await Campaign.remainBalance();
    console.log("resultAfterUserPay:" + resultAfterUserPay);
    console.log("pushPay complated");

    //   expect(resultAfterUserPay).to.equal(100000 - 200 - 40);
}



async function deployAD3HubFixture() {
    // Get the ContractFactory and Signers here.
    const AD3Hub = await ethers.getContractFactory("AD3Hub");
    const [owner, addr1, addr2] = await ethers.getSigners();

    const ad3Hub = await AD3Hub.deploy();
    await ad3Hub.deployed();
    console.log("AD3Hub.deploy hash:"+ ad3Hub.deployTransaction.hash);

    let customHttpProvider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545");
    let info = await customHttpProvider.getTransactionReceipt(ad3Hub.deployTransaction.hash);
    console.log("AD3Hub.deploy gas used:" + info.gasUsed);
    // Fixtures can return anything you consider useful for your tests
    return { ad3Hub, owner, addr1, addr2 };
}

async function deployCampaignImpl() {
    // Get the ContractFactory and Signers here.
    const Campaign = await ethers.getContractFactory("Campaign");

    const campaign = await Campaign.deploy();
    await campaign.deployed();
    let customHttpProvider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545");
    let info = await customHttpProvider.getTransactionReceipt(campaign.deployTransaction.hash);
    console.log("Campaign.deploy() gas used:" + info.gasUsed);
    // Fixtures can return anything you consider useful for your tests
    return campaign.address;
}

// token of payment
async function deployPaymentToken() {
    const USDT = await ethers.getContractFactory("TetherToken");
    const token = await USDT.deploy(10 ** 9, "USDT", "USDT", 2);
    await token.deployed();
    return { token };
}


//kols for deployment
async function getKolsFixtrue() {
    const [owner, addr1, addr2] = await ethers.getSigners();
    let kols = [
        {
            kolAddress: addr1.getAddress(),
            fixedFee: 100,
            ratio: 70,
            paymentStage: 0,
        },
        {
            kolAddress: addr2.getAddress(),
            fixedFee: 100,
            ratio: 70,
            paymentStage: 0,
        }
    ];

    // for (let i = 0; i < 1000; i++) {
    //     kols.push(
    //         {
    //             _address: addr2.getAddress(),
    //             fixedFee: 100,
    //             ratio: 70,
    //             _paymentStage: 0
    //         }
    //     );
    // }
    return kols;
}

//kols for pushpay
async function getKolWithUsers() {
    const [owner, addr1, addr2, addr3, addr4, addr5, addr6, addr7] = await ethers.getSigners();
    let userList = [];
    for (let i = 0; i < 20; i++) {
        userList.push(addr6.getAddress());
    }
    let kolWithUsers = [
        {
            kolAddress: addr1.getAddress(),
            users: [addr3.getAddress(), addr4.getAddress()]
        },
        {
            kolAddress: addr2.getAddress(),
            users: userList
        }
    ];

    return kolWithUsers;
}

//kols for pushPayKol
async function getKolWithUserQuantity() {
    const [owner, addr1, addr2, addr3, addr4, addr5, addr6, addr7] = await ethers.getSigners();

    let kolWithQuantity = [
        {
            kolAddress: addr1.getAddress(),
            quantity: 10
        },
        {
            kolAddress: addr2.getAddress(),
            quantity: 20
        }
    ];

    return kolWithQuantity;
}

//kols for payfixFee
async function getKolsAddress() {
    const [owner, addr1, addr2] = await ethers.getSigners();
    let kols = [
        addr1.getAddress(),
        addr2.getAddress()
    ];
    return kols;
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });