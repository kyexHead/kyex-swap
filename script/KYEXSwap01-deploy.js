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
        3, //platformFee : 0.3%
        ethers.ZeroAddress, //connectorAddress
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
      platformFee: 3,
      KYEXSwap01Proxy: KYEXSwap01Proxy,
      deployer: deployer,
    };
  } else if (network.name == "zeta_test") {
    const KYEXSwap01Factory = await ethers.getContractFactory("KYEXSwap01");
    const KYEXSwap01 = await KYEXSwap01Factory.deploy();
    await KYEXSwap01.waitForDeployment();
    console.log(await KYEXSwap01.getAddress());
    await KYEXSwap01.initialize(
      "0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf",
      "0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe",
      "0x9fd96203f7b22bCF72d9DCb40ff98302376cE09c",
      deployer.address,
      600,
      0,
      "0x239e96c8f17c85c30100ac26f635ea15f23e9c67"
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

module.exports = { deployKyexSwap01 };
if (require.main === module) {
  deployKyexSwap01().then(() => process.exit(0));
}
