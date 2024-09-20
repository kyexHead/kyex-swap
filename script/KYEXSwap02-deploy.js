const { ethers, upgrades, network } = require("hardhat");
async function deployKyexSwap02() {
  const [deployer] = await ethers.getSigners();

  if (network.name == "hardhat") {
    // deploy WZETA
    const WZETA = await ethers.getContractFactory("WZETA");
    const wzeta = await WZETA.deploy();
    await wzeta.waitForDeployment();
    const wzetaAddr = await wzeta.getAddress();
    console.log("wzeta address:", wzetaAddr);

    // deploy UniswapV2Factory
    const UniswapV2Factory = await ethers.getContractFactory(
      "UniswapV2Factory"
    );
    const UniswapFactory = await UniswapV2Factory.deploy(deployer.address);
    await UniswapFactory.waitForDeployment();
    const UniswapFactoryAddr = await UniswapFactory.getAddress();
    console.log("UniswapFactory address:", UniswapFactoryAddr);

    // deploy UniswapV2Router02
    const UniswapV2Router02 = await ethers.getContractFactory(
      "TestUniswapRouter"
    );
    const UniswapRouter = await UniswapV2Router02.deploy(
      UniswapFactoryAddr,
      wzetaAddr
    );
    await UniswapRouter.waitForDeployment();
    const UniswapRouterAddr = await UniswapRouter.getAddress();
    console.log("UniswapRouter address:", UniswapRouterAddr);

    //deploy MockSystemContract
    const MockSystemContractFactory = await ethers.getContractFactory(
      "MockSystemContract"
    );
    const MockSystemContract = await MockSystemContractFactory.deploy(
      wzetaAddr,
      UniswapFactoryAddr,
      UniswapRouterAddr
    );
    await MockSystemContract.waitForDeployment();
    const MockSystemContractAddr = await MockSystemContract.getAddress();
    console.log("MockSystemContract address:", MockSystemContractAddr);

    // deploy KYEXSwap02 proxy
    const KYEXSwap02Factory = await ethers.getContractFactory("KYEXSwap02");
    const KYEXSwap02Proxy = await upgrades.deployProxy(
      KYEXSwap02Factory,
      [
        wzetaAddr,
        deployer.address,
        600, //MAX_DEADLINE
        0, //platformFee
        500, //MAX_SLIPPAGE
        MockSystemContractAddr,
      ],
      { initializer: "initialize", kind: "uups" }
    );
    await KYEXSwap02Proxy.waitForDeployment();
    console.log("KYEXSwap02Proxy address:", await KYEXSwap02Proxy.getAddress());

    return {
      WZETA: wzeta,
      MAX_DEADLINE: 600,
      platformFee: 0,
      MAX_SLIPPAGE: 500,
      KYEXSwap02Proxy: KYEXSwap02Proxy,
      deployer: deployer,
      MockSystemContract: MockSystemContract,
      UniswapFactory: UniswapFactory,
      UniswapRouter: UniswapRouter,
    };
  } else if (network.name == "zeta_test") {
    // TODO
  } else if (network.name == "zeta_mainnet") {
    // TODO
  }
}

module.exports = { deployKyexSwap02 };
if (require.main === module) {
  deployKyexSwap02().then(() => process.exit(0));
}
