const { deployKyexSwap02 } = require("../script/KYEXSwap02-deploy.js");
const { createUniswapPair } = require("./library/createUniswapPair.js");
const { upgrades, ethers } = require("hardhat");
const { expect } = require("chai");
const { AbiCoder } = require("ethers");

const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Test deployment and initialization", function () {
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
// Test onCrossChainCall
///////////////////

// Depreciated
// describe("Test isWithdraw is 0", function () {
//   it("Should be swap correctly", async function () {
//     const {
//       WZETA,
//       KYEXSwap02Proxy,
//       deployer,
//       MockSystemContract,
//       UniswapRouter,
//       UniswapFactory,
//     } = await loadFixture(deployKyexSwap02);
//     await WZETA.connect(deployer).deposit({
//       value: ethers.parseUnits("1000", 18),
//     });
//     const MockZRC20Factory = await ethers.getContractFactory("MockZRC20");
//     const MockZRC20ETH = await MockZRC20Factory.connect(deployer).deploy(
//       1000,
//       "ETH",
//       "ETH"
//     );
//     const MockZRC20USDC = await MockZRC20Factory.connect(deployer).deploy(
//       1000,
//       "USDC",
//       "USDC"
//     );
//     await MockZRC20USDC.setGasFee(ethers.parseUnits("5", 18));
//     const deployerAddr = await deployer.getAddress();

//     await createUniswapPair(
//       deployerAddr,
//       UniswapRouter,
//       UniswapFactory,
//       MockZRC20ETH,
//       WZETA
//     );

//     await createUniswapPair(
//       deployerAddr,
//       UniswapRouter,
//       UniswapFactory,
//       MockZRC20USDC,
//       WZETA
//     );

//     const MockSystemContractAddr = await MockSystemContract.getAddress();
//     const amountIn = ethers.parseUnits("10", 18);
//     await MockZRC20ETH.connect(deployer).transfer(
//       MockSystemContractAddr,
//       amountIn
//     );

//     const recipient = ethers.hexlify(deployerAddr);
//     const MockZRC20USDCAddr = await MockZRC20USDC.getAddress();
//     const MockZRC20ETHAddr = await MockZRC20ETH.getAddress();

//     const message = new AbiCoder().encode(
//       ["uint32", "uint32", "address", "bytes"],
//       [0, 10, ethers.ZeroAddress, recipient]
//     );
//     const KYEXSwap02ProxyAddr = await KYEXSwap02Proxy.getAddress();
//     const tx = await MockSystemContract.connect(deployer).onCrossChainCall(
//       1337,
//       KYEXSwap02ProxyAddr,
//       MockZRC20ETHAddr,
//       amountIn,
//       message
//     );
//     await expect(tx).to.emit(KYEXSwap02Proxy, "TokenWithdrawal");
//     expect(await MockZRC20ETH.balanceOf(deployerAddr)).to.equal(
//       ethers.parseUnits("490", 18)
//     );
//     expect(await MockZRC20USDC.balanceOf(deployerAddr)).to.be.gt(
//       ethers.parseUnits("500", 18)
//     );
//   });
// });

// Depreciated
// describe("Test isWithdraw is 3", function () {
//   it("Should be swap correctly", async function () {
//     const {
//       WZETA,
//       KYEXSwap02Proxy,
//       deployer,
//       MockSystemContract,
//       UniswapRouter,
//       UniswapFactory,
//     } = await loadFixture(deployKyexSwap02);

//     await WZETA.connect(deployer).deposit({
//       value: ethers.parseUnits("500", 18),
//     });
//     const deployerAddr = await deployer.getAddress();

//     const MockZRC20Factory = await ethers.getContractFactory("MockZRC20");
//     const MockZRC20ETH = await MockZRC20Factory.connect(deployer).deploy(
//       1500,
//       "ETH",
//       "ETH"
//     );
//     const MockZRC20ETHAddr = await MockZRC20ETH.getAddress();

//     await createUniswapPair(
//       deployerAddr,
//       UniswapRouter,
//       UniswapFactory,
//       MockZRC20ETH,
//       WZETA
//     );

//     const MockZRC20USDC = await MockZRC20Factory.connect(deployer).deploy(
//       1000,
//       "USDC",
//       "USDC"
//     );

//     await createUniswapPair(
//       deployerAddr,
//       UniswapRouter,
//       UniswapFactory,
//       MockZRC20ETH,
//       MockZRC20USDC
//     );

//     const MockSystemContractAddr = await MockSystemContract.getAddress();
//     const amountIn = ethers.parseUnits("10", 18);
//     await MockZRC20ETH.connect(deployer).transfer(
//       MockSystemContractAddr,
//       amountIn
//     );

//     const recipient = ethers.hexlify(deployerAddr);
//     const MockZRC20USDCAddr = await MockZRC20USDC.getAddress();

//     const message = new AbiCoder().encode(
//       ["uint32", "uint32", "address", "bytes"],
//       [3, 10, MockZRC20USDCAddr, recipient]
//     );
//     const KYEXSwap02ProxyAddr = await KYEXSwap02Proxy.getAddress();
//     const tx = await MockSystemContract.connect(deployer).onCrossChainCall(
//       1337,
//       KYEXSwap02ProxyAddr,
//       MockZRC20ETHAddr,
//       amountIn,
//       message
//     );
//     await expect(tx).to.emit(KYEXSwap02Proxy, "WrappedTokenTransfer");
//     expect(await MockZRC20ETH.balanceOf(deployerAddr)).to.equal(
//       ethers.parseUnits("490", 18)
//     );
//     expect(await MockZRC20USDC.balanceOf(deployerAddr)).to.be.gt(
//       ethers.parseUnits("500", 18)
//     );
//   });
// });

describe("Test isWithdraw is 4", function () {
  it("Should be swap correctly", async function () {
    const {
      WZETA,
      KYEXSwap02Proxy,
      deployer,
      MockSystemContract,
      UniswapFactory,
      UniswapRouter,
    } = await loadFixture(deployKyexSwap02);

    await WZETA.connect(deployer).deposit({
      value: ethers.parseUnits("500", 18),
    });

    const MockZRC20Factory = await ethers.getContractFactory("MockZRC20");
    const MockZRC20ETH = await MockZRC20Factory.connect(deployer).deploy(
      1500,
      "ETH",
      "ETH"
    );

    const deployerAddr = await deployer.getAddress();

    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      MockZRC20ETH,
      WZETA
    );
    const MockSystemContractAddr = await MockSystemContract.getAddress();
    const amountIn = ethers.parseUnits("10", 18);
    await MockZRC20ETH.connect(deployer).transfer(
      MockSystemContractAddr,
      amountIn
    );

    const recipient = ethers.hexlify(deployerAddr);
    const MockZRC20ETHAddr = await MockZRC20ETH.getAddress();

    const message = new AbiCoder().encode(
      ["uint32", "uint32", "address", "bytes"],
      [4, 10, ethers.ZeroAddress, recipient]
    );
    const KYEXSwap02ProxyAddr = await KYEXSwap02Proxy.getAddress();
    const tx = await MockSystemContract.connect(deployer).onCrossChainCall(
      1337,
      KYEXSwap02ProxyAddr,
      MockZRC20ETHAddr,
      amountIn,
      message
    );
    await expect(tx).to.emit(KYEXSwap02Proxy, "WrappedTokenTransfer");
    expect(await MockZRC20ETH.balanceOf(deployerAddr)).to.equal(
      ethers.parseUnits("1000", 18)
    );
  });
});

describe("Test targetToken is WZETA && isWithdraw is 1", function () {
  it("Should be swap correctly", async function () {
    const {
      WZETA,
      KYEXSwap02Proxy,
      deployer,
      MockSystemContract,
      UniswapRouter,
      UniswapFactory,
    } = await loadFixture(deployKyexSwap02);
    await WZETA.connect(deployer).deposit({
      value: ethers.parseUnits("1000", 18),
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
      MockZRC20ETH,
      WZETA
    );

    const MockSystemContractAddr = await MockSystemContract.getAddress();
    const amountIn = ethers.parseUnits("10", 18);
    await MockZRC20ETH.connect(deployer).transfer(
      MockSystemContractAddr,
      amountIn
    );

    const recipient = ethers.hexlify(deployerAddr);
    const WZETAAddr = await WZETA.getAddress();
    const MockZRC20ETHAddr = await MockZRC20ETH.getAddress();

    const message = new AbiCoder().encode(
      ["uint32", "uint32", "address", "bytes"],
      [1, 10, WZETAAddr, recipient]
    );
    const KYEXSwap02ProxyAddr = await KYEXSwap02Proxy.getAddress();
    const tx = await MockSystemContract.connect(deployer).onCrossChainCall(
      1337,
      KYEXSwap02ProxyAddr,
      MockZRC20ETHAddr,
      amountIn,
      message
    );
    await expect(tx)
      .to.emit(KYEXSwap02Proxy, "WrappedTokenTransfer")
      .and.emit(KYEXSwap02Proxy, "SwapExecuted")
      .and.emit(KYEXSwap02Proxy, "DebugInfo");

    expect(await MockZRC20ETH.balanceOf(deployerAddr)).to.equal(
      ethers.parseUnits("490", 18)
    );
    expect(await WZETA.balanceOf(deployerAddr)).to.be.gt(
      ethers.parseUnits("500", 18)
    );
  });
});

describe("Test targetToken is WZETA && isWithdraw is 2", function () {
  it("Should be swap correctly", async function () {
    const {
      WZETA,
      KYEXSwap02Proxy,
      deployer,
      MockSystemContract,
      UniswapRouter,
      UniswapFactory,
    } = await loadFixture(deployKyexSwap02);
    await WZETA.connect(deployer).deposit({
      value: ethers.parseUnits("1000", 18),
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
      MockZRC20ETH,
      WZETA
    );

    const MockSystemContractAddr = await MockSystemContract.getAddress();
    const amountIn = ethers.parseUnits("10", 18);
    await MockZRC20ETH.connect(deployer).transfer(
      MockSystemContractAddr,
      amountIn
    );

    const recipient = ethers.hexlify(deployerAddr);
    const WZETAAddr = await WZETA.getAddress();
    const MockZRC20ETHAddr = await MockZRC20ETH.getAddress();

    const message = new AbiCoder().encode(
      ["uint32", "uint32", "address", "bytes"],
      [2, 10, WZETAAddr, recipient]
    );
    const KYEXSwap02ProxyAddr = await KYEXSwap02Proxy.getAddress();
    const tx = await MockSystemContract.connect(deployer).onCrossChainCall(
      1337,
      KYEXSwap02ProxyAddr,
      MockZRC20ETHAddr,
      amountIn,
      message
    );
    await expect(tx)
      .to.emit(KYEXSwap02Proxy, "UnWrapZetaTokenTransfer")
      .and.emit(KYEXSwap02Proxy, "SwapExecuted")
      .and.emit(KYEXSwap02Proxy, "DebugInfo");

    expect(await MockZRC20ETH.balanceOf(deployerAddr)).to.equal(
      ethers.parseUnits("490", 18)
    );
    //1000 - 500
    expect(await WZETA.balanceOf(deployerAddr)).to.equal(
      ethers.parseUnits("500", 18)
    );
    //10000 - 1000 + amountOut
    expect(await ethers.provider.getBalance(deployerAddr)).to.be.gt(9000);
  });
});

describe("Test targetToken is ZRC20 && isWithdraw is 1", function () {
  it("Should be swap correctly", async function () {
    const {
      WZETA,
      KYEXSwap02Proxy,
      deployer,
      MockSystemContract,
      UniswapRouter,
      UniswapFactory,
    } = await loadFixture(deployKyexSwap02);

    await WZETA.connect(deployer).deposit({
      value: ethers.parseUnits("1000", 18),
    });
    const MockZRC20Factory = await ethers.getContractFactory("MockZRC20");
    const MockZRC20ETH = await MockZRC20Factory.connect(deployer).deploy(
      1500,
      "ETH",
      "ETH"
    );
    const deployerAddr = await deployer.getAddress();
    const MockZRC20ETHAddr = await MockZRC20ETH.getAddress();
    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      MockZRC20ETH,
      WZETA
    );

    const MockZRC20USDC = await MockZRC20Factory.connect(deployer).deploy(
      1000,
      "USDC",
      "USDC"
    );
    await MockZRC20USDC.setGasFee(ethers.parseUnits("5", 18));

    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      MockZRC20ETH,
      MockZRC20USDC
    );

    const MockSystemContractAddr = await MockSystemContract.getAddress();
    const amountIn = ethers.parseUnits("10", 18);
    await MockZRC20ETH.connect(deployer).transfer(
      MockSystemContractAddr,
      amountIn
    );

    const recipient = ethers.hexlify(deployerAddr);
    const MockZRC20USDCAddr = await MockZRC20USDC.getAddress();

    const message = new AbiCoder().encode(
      ["uint32", "uint32", "address", "bytes"],
      [1, 10, MockZRC20USDCAddr, recipient]
    );
    const KYEXSwap02ProxyAddr = await KYEXSwap02Proxy.getAddress();
    const tx = await MockSystemContract.connect(deployer).onCrossChainCall(
      1337,
      KYEXSwap02ProxyAddr,
      MockZRC20ETHAddr,
      amountIn,
      message
    );

    await expect(tx)
      .to.emit(KYEXSwap02Proxy, "WrappedTokenTransfer")
      .and.emit(KYEXSwap02Proxy, "SwapExecuted")
      .and.emit(KYEXSwap02Proxy, "DebugInfo");
    expect(await MockZRC20ETH.balanceOf(deployerAddr)).to.equal(
      ethers.parseUnits("490", 18)
    );
    expect(await MockZRC20USDC.balanceOf(deployerAddr)).to.be.gt(
      ethers.parseUnits("500", 18)
    );
  });
});

describe("Test targetToken is ZRC20 && isWithdraw is 2", function () {
  it("Should be swap correctly", async function () {
    const {
      WZETA,
      KYEXSwap02Proxy,
      deployer,
      MockSystemContract,
      UniswapRouter,
      UniswapFactory,
    } = await loadFixture(deployKyexSwap02);

    await WZETA.connect(deployer).deposit({
      value: ethers.parseUnits("1000", 18),
    });

    const MockZRC20Factory = await ethers.getContractFactory("MockZRC20");
    const MockZRC20ETH = await MockZRC20Factory.connect(deployer).deploy(
      1500,
      "ETH",
      "ETH"
    );
    const deployerAddr = await deployer.getAddress();

    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      MockZRC20ETH,
      WZETA
    );
    const MockZRC20USDC = await MockZRC20Factory.connect(deployer).deploy(
      1000,
      "USDC",
      "USDC"
    );
    await MockZRC20USDC.setGasFee(ethers.parseUnits("5", 18));

    await createUniswapPair(
      deployerAddr,
      UniswapRouter,
      UniswapFactory,
      MockZRC20ETH,
      MockZRC20USDC
    );

    const MockSystemContractAddr = await MockSystemContract.getAddress();
    const amountIn = ethers.parseUnits("10", 18);
    await MockZRC20ETH.connect(deployer).transfer(
      MockSystemContractAddr,
      amountIn
    );

    const recipient = ethers.hexlify(deployerAddr);
    const MockZRC20USDCAddr = await MockZRC20USDC.getAddress();
    const MockZRC20ETHAddr = await MockZRC20ETH.getAddress();

    const message = new AbiCoder().encode(
      ["uint32", "uint32", "address", "bytes"],
      [2, 10, MockZRC20USDCAddr, recipient]
    );
    const KYEXSwap02ProxyAddr = await KYEXSwap02Proxy.getAddress();
    const tx = await MockSystemContract.connect(deployer).onCrossChainCall(
      1337,
      KYEXSwap02ProxyAddr,
      MockZRC20ETHAddr,
      amountIn,
      message
    );
    await expect(tx)
      .to.emit(KYEXSwap02Proxy, "TokenWithdrawal")
      .and.emit(KYEXSwap02Proxy, "SwapExecuted")
      .and.emit(KYEXSwap02Proxy, "DebugInfo");
    expect(await MockZRC20ETH.balanceOf(deployerAddr)).to.equal(
      ethers.parseUnits("490", 18)
    );
    expect(await MockZRC20USDC.balanceOf(deployerAddr)).to.be.gt(
      ethers.parseUnits("500", 18)
    );
  });
});
