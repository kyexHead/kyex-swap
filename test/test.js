const { ethers } = require("hardhat");
async function main() {
  const [deployer, testUser] = await ethers.getSigners();
  //   const contractABI = [
  //     "function swapFromZetaChainToAny(address tokenInOfZetaChain,address tokenOutOfZetaChain,uint256 amountIn,bytes memory btcRecipient,uint256 minAmountOut,bool isCrossChain,uint8 chainId) external payable",
  //   ];

  const swap01 = await ethers.getContractAt(
    "KYEXSwap01",
    "0xD42912755319665397FF090fBB63B1a31aE87Cee"
  );

  const tx = await swap01
    .connect(testUser)
    .swapFromZetaChainToAny(
      "0x05BA149A7bd6dC1F937fA9046A9e05C05f3b18b0",
      "0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891",
      ethers.parseUnits("0.1", 18),
      "0x307830303030303030303030303030303030303030303030303030303030303030303030303064456144",
      ethers.parseUnits("0.05", 18),
      true,
      97
    );
  console.log(tx);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
