require("@nomiclabs/hardhat-truffle5");
require("@openzeppelin/hardhat-upgrades");

module.exports = {
  networks: {
    hardhat: {
      forking: {
        url: "https://bsc-dataseed.binance.org/",
      },
    },
  },
  mocha: {
    timeout: 2000000,
  },
  solidity: "0.6.6",
};
