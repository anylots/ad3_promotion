require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config({ path: ".env" });
require("hardhat-gas-reporter");

// The next line is part of the sample project, you don't need it in your
// project. It imports a Hardhat task definition, that can be used for
// testing the frontend.
require("./tasks/faucet");

const { GOERLI_PRIVATE_KEY, ALCHEMY_PROJECT_ID } = process.env;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      { version: "0.8.0" },
      { version: "0.4.17" }
    ]
  },
  networks: {
    hardhat: {
      chainId: 1337 // We set 1337 to make interacting with MetaMask simpler
    },
    goerli: {
      url: `https://eth-goerli.g.alchemy.com/v2/${ALCHEMY_PROJECT_ID}`,
      accounts: [GOERLI_PRIVATE_KEY]
    },
    mumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/YbE4U9U8b3M74blue_Un2wTDK83R0M2W1Ksf`,
      accounts: [POLYGON_TEST_PRIVATE_KEY]
    }
  },
  gasReporter: {
    enabled: false,
    gasPrice: 10,
    currency: 'USD',
    token: "ETH"
  }
};
