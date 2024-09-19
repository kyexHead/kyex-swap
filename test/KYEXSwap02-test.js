const { deployKyexSwap02 } = require("../script/KYEXSwap02-deploy.js");
const { createUniswapPair } = require("./library/createUniswapPair.js");
const { upgrades, ethers } = require("hardhat");
const { expect } = require("chai");

const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Test deployment and initialization", function () {
  it("Should be initialized correctly", async function () {
    const {
      WZETA,
      UniswapFactory,
      UniswapRouter,
      MAX_DEADLINE,
      platformFee,
      MAX_SLIPPAGE,
      KYEXSwap02Proxy,
      deployer,
      MockSystemContract,
    } = await loadFixture(deployKyexSwap02);
    expect(await KYEXSwap02Proxy.getWZETA()).to.equal(await WZETA.getAddress());
    expect(await KYEXSwap02Proxy.getUniswapFactory()).to.equal(
      await UniswapFactory.getAddress()
    );
    expect(await KYEXSwap02Proxy.getUniswapRouter()).to.equal(
      await UniswapRouter.getAddress()
    );
    expect(await KYEXSwap02Proxy.getPlatformFee()).to.equal(platformFee);
    expect(await KYEXSwap02Proxy.getMaxSlippage()).to.equal(MAX_SLIPPAGE);
    expect(await KYEXSwap02Proxy.getMaxDeadLine()).to.equal(MAX_DEADLINE);
    expect(await KYEXSwap02Proxy.getSystemContract()).to.equal(
      await MockSystemContract.getAddress()
    );
    expect(await KYEXSwap02Proxy.owner()).to.equal(deployer.address);
  });

  it("Should deploy the proxy correctly ", async function () {
    const { KYEXSwap02Proxy } = await loadFixture(deployKyexSwap02);
    const KYEXSwap02ProxyAddr = await KYEXSwap02Proxy.getAddress();
    const implementationAddr = await upgrades.erc1967.getImplementationAddress(
      KYEXSwap02ProxyAddr
    );
    expect(implementationAddr).to.not.equal(ethers.ZeroAddress);
  });
});

///////////////////
// Test zrcSwapToNative
///////////////////
