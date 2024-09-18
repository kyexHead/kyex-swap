const { deployKyexSwap01 } = require("../script/KYEXSwap01-deploy.js");
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
      KYEXSwap01Proxy,
      deployer,
    } = await loadFixture(deployKyexSwap01);
    expect(await KYEXSwap01Proxy.getWZETA()).to.equal(await WZETA.getAddress());
    expect(await KYEXSwap01Proxy.getUniswapFactory()).to.equal(
      await UniswapFactory.getAddress()
    );
    expect(await KYEXSwap01Proxy.getUniswapRouter()).to.equal(
      await UniswapRouter.getAddress()
    );
    expect(await KYEXSwap01Proxy.getPlatformFee()).to.equal(platformFee);
    expect(await KYEXSwap01Proxy.getMaxSlippage()).to.equal(MAX_SLIPPAGE);
    expect(await KYEXSwap01Proxy.getMaxDeadLine()).to.equal(MAX_DEADLINE);
    expect(await KYEXSwap01Proxy.owner()).to.equal(deployer.address);
  });

  it("Should deploy the proxy correctly ", async function () {
    const { KYEXSwap01Proxy } = await loadFixture(deployKyexSwap01);
    const KYEXSwap01ProxyAddr = await KYEXSwap01Proxy.getAddress();
    const implementationAddr = await upgrades.erc1967.getImplementationAddress(
      KYEXSwap01ProxyAddr
    );
    expect(implementationAddr).to.not.equal(ethers.ZeroAddress);
  });
});

///////////////////
// Test zrcSwapToNative
///////////////////
describe("Test tokenOutOfZetaChain is not equals gasZRC20", function () {
  it("tokenInOfZetaChain is ZETA && isCrossChain is false", async function () {
    const { WZETA, UniswapFactory, UniswapRouter, KYEXSwap01Proxy, deployer } =
      await loadFixture(deployKyexSwap01);

    const amount = ethers.parseUnits("1000", 18);
    await WZETA.connect(deployer).deposit({
      value: amount,
    });
    const MockZRC20Factory = await ethers.getContractFactory("MockZRC20");
    const MockZRC20USDC = await MockZRC20Factory.connect(deployer).deploy(
      1000,
      "USDC",
      "USDC"
    );
    const deployerAddr = await deployer.getAddress();
    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      WZETA,
      MockZRC20USDC
    );

    const WZETAAddr = await WZETA.getAddress();
    const MockZRC20USDCAddr = await MockZRC20USDC.getAddress();

    const MockZRC20ETH = await MockZRC20Factory.connect(deployer).deploy(
      1000,
      "ETH",
      "ETH"
    );
    const MockZRC20ETHAddr = await MockZRC20ETH.getAddress();
    MockZRC20USDC.setGasFeeAddress(MockZRC20ETHAddr);

    const KYEXSwap01ProxyAddr = await KYEXSwap01Proxy.getAddress();
    await WZETA.connect(deployer).approve(
      KYEXSwap01ProxyAddr,
      ethers.parseUnits("10", 18)
    );
    const tx = await KYEXSwap01Proxy.connect(deployer).zrcSwapToNative(
      WZETAAddr,
      MockZRC20USDCAddr,
      ethers.parseUnits("10", 18),
      true,
      ethers.ZeroAddress,
      10,
      false
    );
    await expect(tx)
      .to.emit(KYEXSwap01Proxy, "TokenTransfer")
      .and.to.emit(KYEXSwap01Proxy, "SwapExecuted");
    expect(await WZETA.balanceOf(deployerAddr)).to.equal(
      ethers.parseUnits("490", 18)
    );
    expect(await MockZRC20USDC.balanceOf(deployerAddr)).to.be.gt(
      ethers.parseUnits("500", 18)
    );
  });

  it("tokenInOfZetaChain is ZETA && isCrossChain is true", async function () {
    const { WZETA, UniswapFactory, UniswapRouter, KYEXSwap01Proxy, deployer } =
      await loadFixture(deployKyexSwap01);

    const amount = ethers.parseUnits("1100", 18);
    await WZETA.connect(deployer).deposit({
      value: amount,
    });
    const MockZRC20Factory = await ethers.getContractFactory("MockZRC20");
    const MockZRC20USDC = await MockZRC20Factory.connect(deployer).deploy(
      1000,
      "USDC",
      "USDC"
    );
    const deployerAddr = await deployer.getAddress();
    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      WZETA,
      MockZRC20USDC
    );

    const WZETAAddr = await WZETA.getAddress();
    const MockZRC20USDCAddr = await MockZRC20USDC.getAddress();

    const MockZRC20ETH = await MockZRC20Factory.connect(deployer).deploy(
      1000,
      "ETH",
      "ETH"
    );
    const MockZRC20ETHAddr = await MockZRC20ETH.getAddress();
    MockZRC20USDC.setGasFeeAddress(MockZRC20ETHAddr);
    MockZRC20USDC.setGasFee(10);

    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      WZETA,
      MockZRC20ETH
    );

    const KYEXSwap01ProxyAddr = await KYEXSwap01Proxy.getAddress();
    await WZETA.connect(deployer).approve(
      KYEXSwap01ProxyAddr,
      ethers.parseUnits("10", 18)
    );
    const tx = await KYEXSwap01Proxy.connect(deployer).zrcSwapToNative(
      WZETAAddr,
      MockZRC20USDCAddr,
      ethers.parseUnits("10", 18),
      true,
      ethers.ZeroAddress,
      10,
      true
    );
    await expect(tx)
      .to.emit(MockZRC20USDC, "Withdrawal")
      .and.to.emit(KYEXSwap01Proxy, "SwapExecuted");
    expect(await WZETA.balanceOf(deployerAddr)).to.equal(
      ethers.parseUnits("90", 18)
    );
    expect(await MockZRC20USDC.balanceOf(deployerAddr)).to.be.gt(
      ethers.parseUnits("500", 18)
    );
  });
});

describe("Test tokenOutOfZetaChain equals gasZRC20, but is not equals to WZETA or BITCOIN ", function () {
  it("tokenInOfZetaChain is WZETA && isCrossChain is false", async function () {
    const { WZETA, UniswapFactory, UniswapRouter, KYEXSwap01Proxy, deployer } =
      await loadFixture(deployKyexSwap01);

    const amount = ethers.parseUnits("1000", 18);
    await WZETA.connect(deployer).deposit({
      value: amount,
    });
    const MockZRC20Factory = await ethers.getContractFactory("MockZRC20");
    const MockZRC20ETH = await MockZRC20Factory.connect(deployer).deploy(
      1000,
      "ETH",
      "ETH"
    );
    const deployerAddr = await deployer.getAddress();
    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      WZETA,
      MockZRC20ETH
    );

    const WZETAAddr = await WZETA.getAddress();
    const MockZRC20ETHAddr = await MockZRC20ETH.getAddress();

    const KYEXSwap01ProxyAddr = await KYEXSwap01Proxy.getAddress();
    await WZETA.connect(deployer).approve(
      KYEXSwap01ProxyAddr,
      ethers.parseUnits("10", 18)
    );
    const tx = await KYEXSwap01Proxy.connect(deployer).zrcSwapToNative(
      WZETAAddr,
      MockZRC20ETHAddr,
      ethers.parseUnits("10", 18),
      true,
      ethers.ZeroAddress,
      10,
      false
    );
    await expect(tx)
      .to.emit(KYEXSwap01Proxy, "PerformSwap")
      .and.to.emit(KYEXSwap01Proxy, "TokenTransfer")
      .and.to.emit(KYEXSwap01Proxy, "SwapExecuted");
    expect(await WZETA.balanceOf(deployerAddr)).to.equal(
      ethers.parseUnits("490", 18)
    );
    expect(await MockZRC20ETH.balanceOf(deployerAddr)).to.be.gt(
      ethers.parseUnits("500", 18)
    );
  });

  it("tokenInOfZetaChain is WZETA && isCrossChain is true", async function () {
    const { WZETA, UniswapFactory, UniswapRouter, KYEXSwap01Proxy, deployer } =
      await loadFixture(deployKyexSwap01);

    const amount = ethers.parseUnits("1000", 18);
    await WZETA.connect(deployer).deposit({
      value: amount,
    });
    const MockZRC20Factory = await ethers.getContractFactory("MockZRC20");
    const MockZRC20ETH = await MockZRC20Factory.connect(deployer).deploy(
      1000,
      "ETH",
      "ETH"
    );

    const deployerAddr = await deployer.getAddress();
    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      WZETA,
      MockZRC20ETH
    );

    const WZETAAddr = await WZETA.getAddress();
    const MockZRC20ETHAddr = await MockZRC20ETH.getAddress();
    const KYEXSwap01ProxyAddr = await KYEXSwap01Proxy.getAddress();
    await WZETA.connect(deployer).approve(
      KYEXSwap01ProxyAddr,
      ethers.parseUnits("10", 18)
    );
    const tx = await KYEXSwap01Proxy.connect(deployer).zrcSwapToNative(
      WZETAAddr,
      MockZRC20ETHAddr,
      ethers.parseUnits("10", 18),
      true,
      ethers.ZeroAddress,
      10,
      true
    );
    await expect(tx)
      .to.emit(KYEXSwap01Proxy, "PerformSwap")
      .and.to.emit(MockZRC20ETH, "Withdrawal")
      .and.to.emit(KYEXSwap01Proxy, "SwapExecuted");
    expect(await WZETA.balanceOf(deployerAddr)).to.equal(
      ethers.parseUnits("490", 18)
    );
    expect(await MockZRC20ETH.balanceOf(deployerAddr)).to.be.gt(
      ethers.parseUnits("500", 18)
    );
  });
});

describe("Test tokenOutOfZetaChain equals WZETA ", function () {
  it("tokenInOfZetaChain is ZRC20 && isWarp is true", async function () {
    const { WZETA, UniswapFactory, UniswapRouter, KYEXSwap01Proxy, deployer } =
      await loadFixture(deployKyexSwap01);

    const amount = ethers.parseUnits("500", 18);
    await WZETA.connect(deployer).deposit({
      value: amount,
    });
    const MockZRC20Factory = await ethers.getContractFactory("MockZRC20");
    const MockZRC20ETH = await MockZRC20Factory.connect(deployer).deploy(
      1000,
      "ETH",
      "ETH"
    );
    const deployerAddr = await deployer.getAddress();
    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      WZETA,
      MockZRC20ETH
    );

    const WZETAAddr = await WZETA.getAddress();
    const MockZRC20ETHAddr = await MockZRC20ETH.getAddress();

    const KYEXSwap01ProxyAddr = await KYEXSwap01Proxy.getAddress();
    await MockZRC20ETH.connect(deployer).approve(KYEXSwap01ProxyAddr, amount);
    const tx = await KYEXSwap01Proxy.connect(deployer).zrcSwapToNative(
      MockZRC20ETHAddr,
      WZETAAddr,
      ethers.parseUnits("10", 18),
      true,
      ethers.ZeroAddress,
      10,
      false
    );
    await expect(tx)
      .to.emit(KYEXSwap01Proxy, "PerformSwap")
      .and.to.emit(WZETA, "Transfer")
      .and.to.emit(KYEXSwap01Proxy, "TokenTransfer")
      .and.to.emit(KYEXSwap01Proxy, "SwapExecuted");
    expect(await MockZRC20ETH.balanceOf(deployerAddr)).to.equal(
      ethers.parseUnits("490", 18)
    );
    expect(await WZETA.balanceOf(deployerAddr)).to.be.gt(0);
  });

  it("tokenInOfZetaChain is ZRC20 && isWarp is false", async function () {
    const { WZETA, UniswapFactory, UniswapRouter, KYEXSwap01Proxy, deployer } =
      await loadFixture(deployKyexSwap01);

    const amount = ethers.parseUnits("500", 18);
    await WZETA.connect(deployer).deposit({
      value: amount,
    });
    const MockZRC20Factory = await ethers.getContractFactory("MockZRC20");
    const MockZRC20ETH = await MockZRC20Factory.connect(deployer).deploy(
      1000,
      "ETH",
      "ETH"
    );
    const deployerAddr = await deployer.getAddress();
    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      WZETA,
      MockZRC20ETH
    );

    const WZETAAddr = await WZETA.getAddress();
    const MockZRC20ETHAddr = await MockZRC20ETH.getAddress();

    const KYEXSwap01ProxyAddr = await KYEXSwap01Proxy.getAddress();
    await MockZRC20ETH.connect(deployer).approve(KYEXSwap01ProxyAddr, amount);
    const tx = await KYEXSwap01Proxy.connect(deployer).zrcSwapToNative(
      MockZRC20ETHAddr,
      WZETAAddr,
      ethers.parseUnits("10", 18),
      false,
      ethers.ZeroAddress,
      10,
      false
    );
    await expect(tx)
      .to.emit(KYEXSwap01Proxy, "PerformSwap")
      .and.to.emit(WZETA, "Withdrawal")
      .and.to.emit(KYEXSwap01Proxy, "TokenTransfer")
      .and.to.emit(KYEXSwap01Proxy, "SwapExecuted");
    expect(await MockZRC20ETH.balanceOf(deployerAddr)).to.equal(
      ethers.parseUnits("490", 18)
    );
    //1000 - 500 + amountOut
    expect(await ethers.provider.getBalance(deployerAddr)).to.be.gt(9500);
  });
});
