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
    // const KYEXSwapV1Factory = await ethers.getContractFactory("KYEXSwapV1");
    // const KYEXSwapV1 = await KYEXSwapV1Factory.deploy();
    // await KYEXSwapV1.waitForDeployment();
    // console.log(await KYEXSwapV1.getAddress());
    // await KYEXSwapV1.initialize(
    //   deployer.address,
    //   600,
    //   0,
    //   "0xEdf1c3275d13489aCdC6cD6eD246E72458B8795B",
    //   "0x65a45c57636f9BcCeD4fe193A602008578BcA90b"
    // );
    const KYEXSwapV1ConnectorFactory = await ethers.getContractFactory(
      "KYEXSwapV1TestConnector"
    );
    const KYEXSwapV1Connector = await KYEXSwapV1ConnectorFactory.deploy();
    await KYEXSwapV1Connector.waitForDeployment();
    console.log(await KYEXSwapV1Connector.getAddress());
    await KYEXSwapV1Connector.initialize(
      deployer.address,
      600,
      0,
      "0xEdf1c3275d13489aCdC6cD6eD246E72458B8795B",
      "0x65a45c57636f9BcCeD4fe193A602008578BcA90b",
      "0x239e96c8f17C85c30100AC26F635Ea15f23E9c67"
    );
  } else if (network.name == "zeta_mainnet") {
    const KYEXSwapV1Factory = await ethers.getContractFactory("KYEXSwapV1");
    const KYEXSwapV1Proxy = await upgrades.deployProxy(
      KYEXSwapV1Factory,
      [
        "0x09BD7E006734A022CAd1cf49a41026be9A9e1eB8",
        600,
        0,
        "0x91d18e54DAf4F677cB28167158d6dd21F6aB3921",
        "0x13A0c5930C028511Dc02665E7285134B6d11A5f4",
      ],
      { initializer: "initialize", kind: "uups" }
    );
    await KYEXSwapV1Proxy.waitForDeployment();
    // await KYEXSwapV1Proxy.transferOwnership(
    //   "0x466699d3d58FFd7a7113D4D640F3F5C3698f1bEe"
    // );
    console.log("KYEXSwapV1Proxy address:", await KYEXSwapV1Proxy.getAddress());
  } else if (network.name == "bsc_test") {
    // const KYEXSwapBSCV1Proxy = await upgrades.deployProxy(
    //   KYEXSwapBSCV1Factory,
    //   [
    //     600,
    //     "0x6725F303b657a9451d8BA641348b6761A6CC7a17",
    //     "0xD99D1c33F9fC3444f8101754aBC46c52416550D1",
    //     "0x0000c9ec4042283e8139c74f4c64bcd1e0b9b54f",
    //     "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd",
    //     0,
    //   ],
    //   { initializer: "initialize", kind: "uups" }
    // );
    const KYEXSwapBscV1Factory = await ethers.getContractFactory(
      "KYEXSwapBscV1"
    );
    const KYEXSwapBscV1 = await KYEXSwapBscV1Factory.deploy();
    await KYEXSwapBscV1.waitForDeployment();
    console.log("KYEXSwapBscV1 address:", await KYEXSwapBscV1.getAddress());
    await KYEXSwapBscV1.initialize(
      600,
      "0x6725F303b657a9451d8BA641348b6761A6CC7a17",
      "0xD99D1c33F9fC3444f8101754aBC46c52416550D1",
      "0x0000c9ec4042283e8139c74f4c64bcd1e0b9b54f",
      "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd"
    );
    // const KYEXSwapBscV1 = await ethers.getContractAt(
    //   "KYEXSwapBscV1",
    //   "0x262feddA1a84d4179d27A2a5cA440C330257963A"
    // );
    // const tx = await KYEXSwapBscV1.transferOwnership(
    //   "0xce481C5AF2925325D562f28e5eF2bA4bC8554be9"
    // );
    // console.log(tx);
  }
}

module.exports = { deployKyexSwapV1 };
if (require.main === module) {
  deployKyexSwapV1().then(() => process.exit(0));
}
