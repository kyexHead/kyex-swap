const { deployKyexSwap01 } = require("../script/KYEXSwap01-deploy.js");
const { createUniswapPair } = require("./library/createUniswapPair.js");
const { upgrades, ethers } = require("hardhat");
const { expect } = require("chai");

const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Test deployment and initialization", function () {
  it("Should deploy the proxy correctly ", async function () {
    const { KYEXSwap01Proxy, platformFee } = await loadFixture(
      deployKyexSwap01
    );
    const KYEXSwap01ProxyAddr = await KYEXSwap01Proxy.getAddress();
    const implementationAddr = await upgrades.erc1967.getImplementationAddress(
      KYEXSwap01ProxyAddr
    );
    expect(implementationAddr).to.not.equal(ethers.ZeroAddress);
    expect(await KYEXSwap01Proxy.platformFee()).to.equal(platformFee);
  });
});

///////////////////
// Test swapFromZetaChainToAny
///////////////////
describe("Test non cross chain", function () {
  it("tokenInOfZetaChain is ZETA && tokenOutOfZetaChain is ZRC20", async function () {
    const { WZETA, UniswapFactory, UniswapRouter, KYEXSwap01Proxy, deployer } =
      await loadFixture(deployKyexSwap01);
    const [, user1] = await ethers.getSigners();

    await WZETA.connect(deployer).deposit({
      value: ethers.parseUnits("400", 18),
    });
    const MockZRC20Factory = await ethers.getContractFactory("MockZRC20");
    const MockZRC20USDC = await MockZRC20Factory.connect(deployer).deploy(
      400,
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

    const amountIn = ethers.parseUnits("20", 18);
    const tx = await KYEXSwap01Proxy.connect(user1).swapFromZetaChainToAny(
      WZETAAddr,
      MockZRC20USDCAddr,
      amountIn,
      ethers.ZeroAddress,
      ethers.parseUnits("15", 18),
      false,
      0,
      { value: amountIn }
    );

    const KYEXSwap01ProxyAddr = await KYEXSwap01Proxy.getAddress();

    await expect(tx)
      .to.emit(WZETA, "Deposit")
      .withArgs(KYEXSwap01ProxyAddr, amountIn);

    await expect(tx)
      .to.emit(KYEXSwap01Proxy, "ReceivedToken")
      .withArgs(user1.address, WZETAAddr, amountIn);

    await expect(tx).to.emit(KYEXSwap01Proxy, "PerformSwap");

    await expect(tx).to.emit(KYEXSwap01Proxy, "ReceivePlatformFee");

    await expect(tx).to.emit(KYEXSwap01Proxy, "TokenTransfer");
    // 400 - 400 + PlatformFee > 0
    expect(await MockZRC20USDC.balanceOf(deployerAddr)).to.be.gt(0);
    //1000 - amountIn < 1000
    expect(await ethers.provider.getBalance(user1.address)).to.be.lt(
      ethers.parseUnits("1000", 18)
    );
    //0 + amountOut > 0
    expect(await MockZRC20USDC.balanceOf(user1.address)).to.be.gt(0);
  });

  it("tokenInOfZetaChain is ZRC20 && tokenOutOfZetaChain is ZETA", async function () {
    const { WZETA, UniswapFactory, UniswapRouter, KYEXSwap01Proxy, deployer } =
      await loadFixture(deployKyexSwap01);
    const [, user1] = await ethers.getSigners();

    await WZETA.connect(deployer).deposit({
      value: ethers.parseUnits("400", 18),
    });
    const MockZRC20Factory = await ethers.getContractFactory("MockZRC20");
    const MockZRC20USDC = await MockZRC20Factory.connect(deployer).deploy(
      420,
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
    const amountIn = ethers.parseUnits("20", 18);
    await MockZRC20USDC.connect(deployer).transfer(user1.address, amountIn);

    const WZETAAddr = await WZETA.getAddress();
    const MockZRC20USDCAddr = await MockZRC20USDC.getAddress();
    const KYEXSwap01ProxyAddr = await KYEXSwap01Proxy.getAddress();

    await MockZRC20USDC.connect(user1).approve(KYEXSwap01ProxyAddr, amountIn);
    const tx = await KYEXSwap01Proxy.connect(user1).swapFromZetaChainToAny(
      MockZRC20USDCAddr,
      WZETAAddr,
      amountIn,
      ethers.ZeroAddress,
      ethers.parseUnits("15", 18),
      false,
      0
    );

    await expect(tx)
      .to.emit(MockZRC20USDC, "Transfer")
      .withArgs(user1.address, KYEXSwap01ProxyAddr, amountIn);

    await expect(tx)
      .to.emit(KYEXSwap01Proxy, "ReceivedToken")
      .withArgs(user1.address, MockZRC20USDCAddr, amountIn);

    await expect(tx).to.emit(KYEXSwap01Proxy, "PerformSwap");

    await expect(tx).to.emit(KYEXSwap01Proxy, "ReceivePlatformFee");

    await expect(tx).to.emit(KYEXSwap01Proxy, "TokenTransfer");
    // 400 - 400 + PlatformFee > 0
    expect(await WZETA.balanceOf(deployerAddr)).to.be.gt(0);
    //1000 + amountOut > 1000
    expect(await ethers.provider.getBalance(user1.address)).to.be.gt(
      ethers.parseUnits("1000", 18)
    );
    //20 - amountIn = 0
    expect(await MockZRC20USDC.balanceOf(user1.address)).to.equal(0);
  });

  it("tokenInOfZetaChain is ZRC20 && tokenOutOfZetaChain is ZRC20", async function () {
    const { WZETA, UniswapFactory, UniswapRouter, KYEXSwap01Proxy, deployer } =
      await loadFixture(deployKyexSwap01);
    const [, user1] = await ethers.getSigners();

    await WZETA.connect(deployer).deposit({
      value: ethers.parseUnits("400", 18),
    });
    const MockZRC20Factory = await ethers.getContractFactory("MockZRC20");
    const MockZRC20USDC = await MockZRC20Factory.connect(deployer).deploy(
      820,
      "USDC",
      "USDC"
    );
    const MockZRC20ETH = await MockZRC20Factory.connect(deployer).deploy(
      400,
      "ETH",
      "ETH"
    );

    const deployerAddr = await deployer.getAddress();
    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      MockZRC20ETH,
      MockZRC20USDC
    );
    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      MockZRC20USDC,
      WZETA
    );
    const amountIn = ethers.parseUnits("20", 18);
    await MockZRC20USDC.connect(deployer).transfer(user1.address, amountIn);

    const MockZRC20USDCAddr = await MockZRC20USDC.getAddress();
    const MockZRC20ETHAddr = await MockZRC20ETH.getAddress();

    const KYEXSwap01ProxyAddr = await KYEXSwap01Proxy.getAddress();

    await MockZRC20USDC.connect(user1).approve(KYEXSwap01ProxyAddr, amountIn);
    const tx = await KYEXSwap01Proxy.connect(user1).swapFromZetaChainToAny(
      MockZRC20USDCAddr,
      MockZRC20ETHAddr,
      amountIn,
      ethers.ZeroAddress,
      ethers.parseUnits("15", 18),
      false,
      0
    );

    await expect(tx)
      .to.emit(MockZRC20USDC, "Transfer")
      .withArgs(user1.address, KYEXSwap01ProxyAddr, amountIn);

    await expect(tx)
      .to.emit(KYEXSwap01Proxy, "ReceivedToken")
      .withArgs(user1.address, MockZRC20USDCAddr, amountIn);

    await expect(tx).to.emit(KYEXSwap01Proxy, "PerformSwap");

    await expect(tx).to.emit(KYEXSwap01Proxy, "ReceivePlatformFee");

    await expect(tx).to.emit(KYEXSwap01Proxy, "TokenTransfer");
    // 400 - 400 + PlatformFee > 0
    expect(await MockZRC20ETH.balanceOf(deployerAddr)).to.be.gt(0);
    //0 + amountOut > 0
    expect(await MockZRC20ETH.balanceOf(user1.address)).to.be.gt(0);
    //20 - amountIn = 0
    expect(await MockZRC20USDC.balanceOf(user1.address)).to.equal(0);
  });
});

describe("Test cross chain", function () {
  it("tokenInOfZetaChain is ZETA && tokenOutOfZetaChain is ZRC20 && gasZRC20 is tokenInOfZetaChain", async function () {
    const { WZETA, UniswapFactory, UniswapRouter, KYEXSwap01Proxy, deployer } =
      await loadFixture(deployKyexSwap01);
    const [, user1] = await ethers.getSigners();

    await WZETA.connect(deployer).deposit({
      value: ethers.parseUnits("400", 18),
    });

    const MockZRC20Factory = await ethers.getContractFactory("MockZRC20");
    const MockZRC20USDC = await MockZRC20Factory.connect(deployer).deploy(
      400,
      "USDC",
      "USDC"
    );
    const MockZRC20ETH = await MockZRC20Factory.connect(deployer).deploy(
      820,
      "ETH",
      "ETH"
    );
    const deployerAddr = await deployer.getAddress();
    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      MockZRC20ETH,
      MockZRC20USDC
    );

    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      MockZRC20ETH,
      WZETA
    );

    const WZETAAddr = await WZETA.getAddress();
    const MockZRC20USDCAddr = await MockZRC20USDC.getAddress();
    const MockZRC20ETHAddr = await MockZRC20ETH.getAddress();
    const KYEXSwap01ProxyAddr = await KYEXSwap01Proxy.getAddress();

    await MockZRC20USDC.setGasFee(ethers.parseUnits("1", 18));
    await MockZRC20USDC.setGasFeeAddress(MockZRC20ETHAddr);

    const amountIn = ethers.parseUnits("20", 18);
    await MockZRC20ETH.transfer(user1.address, amountIn);
    await MockZRC20ETH.connect(user1).approve(KYEXSwap01ProxyAddr, amountIn);

    const tx = await KYEXSwap01Proxy.connect(user1).swapFromZetaChainToAny(
      MockZRC20ETHAddr,
      MockZRC20USDCAddr,
      amountIn,
      ethers.ZeroAddress,
      ethers.parseUnits("15", 18),
      true,
      0
    );

    await expect(tx)
      .to.emit(MockZRC20ETH, "Transfer")
      .withArgs(user1.address, KYEXSwap01ProxyAddr, amountIn);

    await expect(tx)
      .to.emit(KYEXSwap01Proxy, "ReceivedToken")
      .withArgs(user1.address, MockZRC20ETHAddr, amountIn);

    await expect(tx).to.emit(KYEXSwap01Proxy, "PerformSwap");

    await expect(tx).to.emit(KYEXSwap01Proxy, "ReceivePlatformFee");

    await expect(tx).to.emit(KYEXSwap01Proxy, "TokenTransfer");
    // 400 - 400  + PlatformFee > 0
    expect(await MockZRC20USDC.balanceOf(deployerAddr)).to.be.gt(0);
    // 0 + amountOut > 0
    expect(await MockZRC20USDC.balanceOf(user1.address)).to.be.gt(0);
    //20 - amountIn > 0
    expect(await MockZRC20ETH.balanceOf(user1.address)).to.equal(0);
  });

  it("tokenInOfZetaChain is ZRC20 && tokenOutOfZetaChain is ZRC20 && gasZRC20 is tokenOutOfZetaChain", async function () {
    const { WZETA, UniswapFactory, UniswapRouter, KYEXSwap01Proxy, deployer } =
      await loadFixture(deployKyexSwap01);
    const [, user1] = await ethers.getSigners();

    await WZETA.connect(deployer).deposit({
      value: ethers.parseUnits("800", 18),
    });
    const MockZRC20Factory = await ethers.getContractFactory("MockZRC20");
    const MockZRC20USDC = await MockZRC20Factory.connect(deployer).deploy(
      420,
      "USDC",
      "USDC"
    );

    const MockZRC20ETH = await MockZRC20Factory.connect(deployer).deploy(
      400,
      "ETH",
      "ETH"
    );
    await MockZRC20ETH.setGasFee(ethers.parseUnits("1", 18));
    const deployerAddr = await deployer.getAddress();
    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      WZETA,
      MockZRC20USDC
    );

    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      WZETA,
      MockZRC20ETH
    );
    const amountIn = ethers.parseUnits("20", 18);
    await MockZRC20USDC.transfer(user1.address, amountIn);

    const MockZRC20ETHAddr = await MockZRC20ETH.getAddress();
    const MockZRC20USDCAddr = await MockZRC20USDC.getAddress();
    const KYEXSwap01ProxyAddr = await KYEXSwap01Proxy.getAddress();

    await MockZRC20USDC.connect(user1).approve(KYEXSwap01ProxyAddr, amountIn);
    const tx = await KYEXSwap01Proxy.connect(user1).swapFromZetaChainToAny(
      MockZRC20USDCAddr,
      MockZRC20ETHAddr,
      amountIn,
      ethers.ZeroAddress,
      ethers.parseUnits("15", 18),
      true,
      0
    );

    await expect(tx)
      .to.emit(MockZRC20USDC, "Transfer")
      .withArgs(user1.address, KYEXSwap01ProxyAddr, amountIn);

    await expect(tx)
      .to.emit(KYEXSwap01Proxy, "ReceivedToken")
      .withArgs(user1.address, MockZRC20USDCAddr, amountIn);

    await expect(tx).to.emit(KYEXSwap01Proxy, "PerformSwap");

    await expect(tx).to.emit(KYEXSwap01Proxy, "ReceivePlatformFee");

    await expect(tx).to.emit(KYEXSwap01Proxy, "TokenTransfer");
    // 400 - 400 + PlatformFee > 0
    expect(await MockZRC20ETH.balanceOf(deployerAddr)).to.be.gt(0);
    //0 + amountOut > 0
    expect(await MockZRC20ETH.balanceOf(user1.address)).to.be.gt(0);
    //20 - amountOut = 0
    expect(await MockZRC20USDC.balanceOf(user1.address)).to.equal(0);
  });

  it("tokenInOfZetaChain is ZRC20 && tokenOutOfZetaChain is ZRC20 && gasZRC20 is not tokenOutOfZetaChain && gasZRC20 is not tokenInOfZetaChain", async function () {
    const { WZETA, UniswapFactory, UniswapRouter, KYEXSwap01Proxy, deployer } =
      await loadFixture(deployKyexSwap01);
    const [, user1] = await ethers.getSigners();

    await WZETA.connect(deployer).deposit({
      value: ethers.parseUnits("400", 18),
    });
    const MockZRC20Factory = await ethers.getContractFactory("MockZRC20");
    const MockZRC20USDC = await MockZRC20Factory.connect(deployer).deploy(
      820,
      "USDC",
      "USDC"
    );

    const MockZRC20ETH = await MockZRC20Factory.connect(deployer).deploy(
      800,
      "ETH",
      "ETH"
    );

    const MockZRC20BNB = await MockZRC20Factory.connect(deployer).deploy(
      400,
      "BNB",
      "BNB"
    );

    const MockZRC20ETHAddr = await MockZRC20ETH.getAddress();
    const MockZRC20USDCAddr = await MockZRC20USDC.getAddress();
    const MockZRC20BNBAddr = await MockZRC20BNB.getAddress();
    const KYEXSwap01ProxyAddr = await KYEXSwap01Proxy.getAddress();

    await MockZRC20ETH.setGasFee(ethers.parseUnits("1", 18));
    await MockZRC20ETH.setGasFeeAddress(MockZRC20BNBAddr);

    const deployerAddr = await deployer.getAddress();
    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      MockZRC20USDC,
      MockZRC20ETH
    );

    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      WZETA,
      MockZRC20USDC
    );

    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      MockZRC20BNB,
      MockZRC20ETH
    );

    const amountIn = ethers.parseUnits("20", 18);
    await MockZRC20USDC.transfer(user1.address, amountIn);
    await MockZRC20USDC.connect(user1).approve(KYEXSwap01ProxyAddr, amountIn);
    const tx = await KYEXSwap01Proxy.connect(user1).swapFromZetaChainToAny(
      MockZRC20USDCAddr,
      MockZRC20ETHAddr,
      amountIn,
      ethers.ZeroAddress,
      ethers.parseUnits("15", 18),
      true,
      0
    );

    await expect(tx)
      .to.emit(MockZRC20USDC, "Transfer")
      .withArgs(user1.address, KYEXSwap01ProxyAddr, amountIn);

    await expect(tx)
      .to.emit(KYEXSwap01Proxy, "ReceivedToken")
      .withArgs(user1.address, MockZRC20USDCAddr, amountIn);

    await expect(tx).to.emit(KYEXSwap01Proxy, "PerformSwap");

    await expect(tx).to.emit(KYEXSwap01Proxy, "ReceivePlatformFee");

    await expect(tx).to.emit(KYEXSwap01Proxy, "TokenTransfer");
    // 800 - 400 - 400 + PlatformFee > 0
    expect(await MockZRC20ETH.balanceOf(deployerAddr)).to.be.gt(0);
    //0 + amountOut > 0
    expect(await MockZRC20ETH.balanceOf(user1.address)).to.be.gt(0);
    //20 - amountOut = 0
    expect(await MockZRC20USDC.balanceOf(user1.address)).to.equal(0);
  });
});
