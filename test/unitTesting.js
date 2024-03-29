const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const Campaign_Artifact = require("../artifacts/contracts/Campaign.sol/Campaign.json")
const Token_Artifact = require("../artifacts/contracts/Token.sol/TetherToken.json")
require("hardhat-gas-reporter");

// Ad3 contract uniting test
describe("Ad3 contract", function () {

  async function deployAD3HubFixture() {
    // Get the ContractFactory and Signers here.
    const AD3Hub = await ethers.getContractFactory("AD3Hub");
    const [owner, addr1, addr2] = await ethers.getSigners();

    const ad3Hub = await AD3Hub.deploy();
    await ad3Hub.deployed();
    // Fixtures can return anything you consider useful for your tests
    return { ad3Hub, owner, addr1, addr2 };
  }


  // token of payment
  async function deployPaymentToken() {
    const USDT = await ethers.getContractFactory("TetherToken");
    const token = await USDT.deploy(10 ** 12); //totalSupply = $10 ** 6
    await token.deployed();
    return { token };
  }


  async function deployCampaignImpl() {
    // Get the ContractFactory and Signers here.
    const Campaign = await ethers.getContractFactory("Campaign");

    const campaign = await Campaign.deploy();
    await campaign.deployed();
    // Fixtures can return anything you consider useful for your tests
    return { campaign };
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
    return kols;
  }

  //kols for pushpay
  async function getKolWithUsers() {
    const [owner, addr1, addr2, addr3, addr4, addr5, addr6, addr7] = await ethers.getSigners();
    let kolWithUsers = [
      {
        kolAddress: addr1.getAddress(),
        users: [addr3.getAddress(), addr4.getAddress()]
      },
      {
        kolAddress: addr2.getAddress(),
        users: [addr5.getAddress(), addr6.getAddress()]

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
          quantity: 2
      },
      {
          kolAddress: addr2.getAddress(),
          quantity: 3
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

  // Test Deployment of Hub
  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { ad3Hub, owner } = await loadFixture(deployAD3HubFixture);
      //Check ad3Hub's owner
      expect(await ad3Hub.owner()).to.equal(owner.address);
    });

    it("Should paymentAddess of ad3Hub equals setPaymentToken", async function () {
      const { ad3Hub, owner } = await loadFixture(deployAD3HubFixture);
      const { token } = await deployPaymentToken();

      //Set and Check paymentToken
      await ad3Hub.setPaymentToken(token.address);
      let payment = await ad3Hub.getPaymentToken();
      console.log("paymentAddess:" + payment);
      expect(payment).to.equal(token.address);
    });
  });



  // Test createCampaign
  describe("CreateCampaign", function () {
    it("create a campaign", async function () {
      const { ad3Hub, owner } = await loadFixture(deployAD3HubFixture);
      const { token } = await deployPaymentToken();
      await ad3Hub.setPaymentToken(token.address);

      const { campaign } = await deployCampaignImpl();
      await ad3Hub.setCampaignImpl(campaign.address);

      await ad3Hub.getCampaignAddressList(owner.address);
      await ad3Hub.getCampaignAddress(owner.address, 1);

      
      await token.approve(ad3Hub.address, 100000);

      //Create campaign
      let kols = await getKolsFixtrue();
      console.log("starting createCampaign");
      await ad3Hub.createCampaign(kols, 100000, 10);


      //Check campaign's address
      let campaignAddress = await ad3Hub.getCampaignAddress(owner.address, 1);
      console.log(campaignAddress);
      let campaignAddressList = await ad3Hub.getCampaignAddressList(owner.address);
      console.log(campaignAddressList);
      expect(1).to.equal(campaignAddressList.length);
      expect(campaignAddress).to.equal(campaignAddressList[0]);


      //Check campaign's balance
      let Campaign = new ethers.Contract(
        campaignAddress,
        Campaign_Artifact.abi,
        owner
      );
      let result = await Campaign.remainBalance();
      console.log("campaign initial balance:" + result);
      expect(result).to.equal(100000);
      // await Campaign.setServiceCharge(1);
    });

    //create two campaign
  });


  // Test Payment
  describe("Payment", function () {
    it("payfixFee", async function () {
      const { ad3Hub, owner } = await loadFixture(deployAD3HubFixture);
      const { token } = await deployPaymentToken();
      await ad3Hub.setPaymentToken(token.address);

      const { campaign } = await deployCampaignImpl();
      await ad3Hub.setCampaignImpl(campaign.address);

      await token.approve(ad3Hub.address, 100000);
      let kols = await getKolsFixtrue();
      await ad3Hub.createCampaign(kols, 100000, 10);
      let campaignAddress = await ad3Hub.getCampaignAddress(owner.address, 1);

      let Campaign = new ethers.Contract(
        campaignAddress,
        Campaign_Artifact.abi,
        owner
      );
      let resultBeforePay = await Campaign.remainBalance();
      console.log("resultBeforePay:" + resultBeforePay);

      //PayFixFee and check campaign's balance
      let kolAddress = await getKolsAddress();
      //first kol pay
      await ad3Hub.payfixFee(kolAddress, owner.address, 1);
      let resultAfterFirstPay = await Campaign.remainBalance();
      console.log("resultAfterFirstPay:" + resultAfterFirstPay);
      expect(resultAfterFirstPay).to.equal(100000 - 100);
      //second kol pay
      await ad3Hub.payfixFee(kolAddress, owner.address, 1);
      let resultAfterSecondPay = await Campaign.remainBalance();
      console.log("resultAfterSecondPay:" + resultAfterSecondPay);
      expect(resultAfterSecondPay).to.equal(100000 - 200);

    });


    it("pushPay and withdraw", async function () {
      const { ad3Hub, owner } = await loadFixture(deployAD3HubFixture);
      const { token } = await deployPaymentToken();
      await ad3Hub.setPaymentToken(token.address);

      const { campaign } = await deployCampaignImpl();
      await ad3Hub.setCampaignImpl(campaign.address);

      await token.approve(ad3Hub.address, 100000);
      let kols = await getKolsFixtrue();
      await ad3Hub.createCampaign(kols, 100000, 10);

      let campaignAddress = await ad3Hub.getCampaignAddress(owner.address, 1);
      let Campaign = new ethers.Contract(
        campaignAddress,
        Campaign_Artifact.abi,
        owner
      );
      let resultBeforePay = await Campaign.remainBalance();
      console.log("campaignBalance_BeforePay:" + resultBeforePay);

      let kolAddress = await getKolsAddress();
      //first kol pay
      await ad3Hub.payfixFee(kolAddress, owner.address, 1);
      //second kol pay
      await ad3Hub.payfixFee(kolAddress, owner.address, 1);


      //UserPay and check campaign's balance
      let kolWithUsers = await getKolWithUsers();
      await ad3Hub.pushPay(owner.address, 1, kolWithUsers);

      let resultAfterUserPay = await Campaign.remainBalance();
      console.log("campaignBalance_AfterUserPay:" + resultAfterUserPay);
      expect(resultAfterUserPay).to.equal(100000 - 200 - 40);//4 users

      let userBalance = await token.balanceOf(kolWithUsers[1].users[1]);
      console.log("userBalance:" + userBalance);// 3

      //Withdraw and check campaign's balance
      let creatorBalance = await token.balanceOf(owner.address);
      console.log("creatorBalance:" + creatorBalance);
      await ad3Hub.withdraw(owner.address, 1);
      let remainBalanceAfterwithdraw = await Campaign.remainBalance();
      console.log("campaignBalance_AfterWithdraw:" + remainBalanceAfterwithdraw);
      expect(remainBalanceAfterwithdraw).to.equal(0);

      //Check creator's balance after Withdraw
      let creatorWithdraw = await token.balanceOf(owner.address);
      console.log("creatorBalance_AfterWithdraw:" + creatorWithdraw);
      expect(creatorWithdraw).to.equal(BigInt(creatorBalance) + BigInt(resultAfterUserPay));
      expect(creatorWithdraw).to.equal(999999999760);
    });



    it("pushPayKol and withdraw", async function () {
      const { ad3Hub, owner } = await loadFixture(deployAD3HubFixture);
      const { token } = await deployPaymentToken();
      await ad3Hub.setPaymentToken(token.address);

      const { campaign } = await deployCampaignImpl();
      await ad3Hub.setCampaignImpl(campaign.address);

      await token.approve(ad3Hub.address, 100000);
      let kols = await getKolsFixtrue();
      await ad3Hub.createCampaign(kols, 100000, 10);

      let campaignAddress = await ad3Hub.getCampaignAddress(owner.address, 1);
      let Campaign = new ethers.Contract(
        campaignAddress,
        Campaign_Artifact.abi,
        owner
      );
      let resultBeforePay = await Campaign.remainBalance();
      console.log("campaignBalance_BeforePay:" + resultBeforePay);

      let kolAddress = await getKolsAddress();
      //first kol pay
      await ad3Hub.payfixFee(kolAddress, owner.address, 1);
      //second kol pay
      await ad3Hub.payfixFee(kolAddress, owner.address, 1);


      //UserPay and check campaign's balance
      let kolWithQuantity = await getKolWithUserQuantity();
      await ad3Hub.pushPayKol(owner.address, 1, kolWithQuantity);

      let resultAfterUserPay = await Campaign.remainBalance();
      console.log("campaignBalance_AfterUserPay:" + resultAfterUserPay);
      expect(resultAfterUserPay).to.equal(100000 - 200 - 35);//total 5 users, each user = 10 => kol = 7;
      //There are 15 remaining tokens waiting for 5 users to claim


      //Withdraw and check campaign's balance
      let creatorBalance = await token.balanceOf(owner.address);
      console.log("creatorBalance:" + creatorBalance);
      await ad3Hub.withdraw(owner.address, 1);
      let remainBalanceAfterwithdraw = await Campaign.remainBalance();
      console.log("campaignBalance_AfterWithdraw:" + remainBalanceAfterwithdraw);
      expect(remainBalanceAfterwithdraw).to.equal(0);

      //Check creator's balance after Withdraw
      let creatorWithdraw = await token.balanceOf(owner.address);
      console.log("creatorBalance_AfterWithdraw:" + creatorWithdraw);
      expect(creatorWithdraw).to.equal(BigInt(creatorBalance) + BigInt(resultAfterUserPay));
      expect(creatorWithdraw).to.equal(999999999765);
    });
  });

});
