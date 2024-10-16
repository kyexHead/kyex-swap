require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");

//addr:0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
const deployer =
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const user1 =
  "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";
const user2 =
  "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      { version: "0.6.6" /** For uniswap v2 */ },
      { version: "0.8.7" },
      { version: "0.5.10" /** For create2 factory */ },
      { version: "0.5.16" /** For uniswap v2 core*/ },
      { version: "0.4.19" /** For weth*/ },
      { version: "0.8.18" /** For IKYEXSpotFactoryV1*/ },
      { version: "0.8.20" /** For KYEXSwap01*/ },
      { version: "0.8.26" /** For zetaV2*/ },
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
      viaIR: true,
    },
  },
  networks: {
    hardhat: {
      chainId: 1337,
      accounts: [
        { privateKey: deployer, balance: "1000000000000000000000" }, // 1000 ETH
        { privateKey: user1, balance: "1000000000000000000000" },
        { privateKey: user2, balance: "1000000000000000000000" },
      ],
    },
    zeta_test: {
      url: "https://zetachain-athens-evm.blockpi.network/v1/rpc/public",
      chainId: 7001,
      accounts: [deployer],
    },
  },
};
