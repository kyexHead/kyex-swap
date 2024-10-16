const { ethers, upgrades, network } = require("hardhat");
async function deployKyexSwapV1() {
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

    // deploy SystemContract
    const MockSystemContract = await ethers.getContractFactory(
      "contracts/mocks/MockSystemContract.sol:MockSystemContract"
    );
    const SystemContract = await MockSystemContract.deploy(
      wzetaAddr,
      UniswapFactoryAddr,
      UniswapRouterAddr
    );
    await SystemContract.waitForDeployment();
    const SystemContractAddr = await SystemContract.getAddress();
    console.log("SystemContract address:", SystemContractAddr);

    // deploy KYEXSwapV1 proxy
    const KYEXSwapV1Factory = await ethers.getContractFactory("KYEXSwapV1");
    const KYEXSwapV1Proxy = await upgrades.deployProxy(
      KYEXSwapV1Factory,
      [
        deployer.address,
        600, //MAX_DEADLINE
        3, //platformFee : 0.3%
        SystemContractAddr,
        ethers.ZeroAddress, //bitCoin
      ],
      { initializer: "initialize", kind: "uups" }
    );
    await KYEXSwapV1Proxy.waitForDeployment();
    console.log("KYEXSwapV1Proxy address:", await KYEXSwapV1Proxy.getAddress());

    return {
      WZETA: wzeta,
      UniswapFactory: UniswapFactory,
      UniswapRouter: UniswapRouter,
      MAX_DEADLINE: 600,
      platformFee: 3,
      SystemContract: SystemContract,
      KYEXSwapV1Proxy: KYEXSwapV1Proxy,
      deployer: deployer,
    };
  } else if (network.name == "zeta_test") {
    const KYEXSwapV1Factory = await ethers.getContractFactory("KYEXSwapV1");
    const KYEXSwapV1 = await KYEXSwapV1Factory.deploy();
    await KYEXSwapV1.waitForDeployment();
    console.log(await KYEXSwapV1.getAddress());
    await KYEXSwapV1.initialize(
      deployer.address,
      600,
      0,
      "0xEdf1c3275d13489aCdC6cD6eD246E72458B8795B",
      "0x65a45c57636f9BcCeD4fe193A602008578BcA90b"
    );

    // const KYEXSwap01Proxy = await upgrades.deployProxy(
    //   KYEXSwap01Factory,
    //   [
    //     "0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf",
    //     "0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe",
    //     "0x9fd96203f7b22bCF72d9DCb40ff98302376cE09c",
    //     deployer.address,
    //     600, //MAX_DEADLINE
    //     0, //platformFee
    //     "0x239e96c8f17C85c30100AC26F635Ea15f23E9c67", //connectorAddress
    //   ],
    //   { initializer: "initialize", kind: "uups" }
    // );
    // await KYEXSwap01Proxy.waitForDeployment();
    // console.log("KYEXSwap01Proxy address:", await KYEXSwap01Proxy.getAddress());
  } else if (network.name == "zeta_mainnet") {
    // TODO
  }
}

module.exports = { deployKyexSwapV1 };
if (require.main === module) {
  deployKyexSwapV1().then(() => process.exit(0));
}
