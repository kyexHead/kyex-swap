const { ethers, upgrades, network } = require("hardhat");
async function deployKyexSwap01() {
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

    // deploy KYEXSwap01 proxy
    const KYEXSwap01Factory = await ethers.getContractFactory("KYEXSwap01");
    const KYEXSwap01Proxy = await upgrades.deployProxy(
      KYEXSwap01Factory,
      [
        wzetaAddr,
        UniswapRouterAddr,
        UniswapFactoryAddr,
        deployer.address,
        600, //MAX_DEADLINE
        0, //platformFee
        500, //MAX_SLIPPAGE
      ],
      { initializer: "initialize", kind: "uups" }
    );
    await KYEXSwap01Proxy.waitForDeployment();
    console.log("KYEXSwap01Proxy address:", await KYEXSwap01Proxy.getAddress());

    return {
      WZETA: wzeta,
      UniswapFactory: UniswapFactory,
      UniswapRouter: UniswapRouter,
      MAX_DEADLINE: 600,
      platformFee: 0,
      MAX_SLIPPAGE: 500,
      KYEXSwap01Proxy: KYEXSwap01Proxy,
      deployer: deployer,
    };
  } else if (network.name == "zeta_test") {
    // TODO
  } else if (network.name == "zeta_mainnet") {
    // TODO
  }
}

module.exports = { deployKyexSwap01 };
if (require.main === module) {
  deployKyexSwap01().then(() => process.exit(0));
}
