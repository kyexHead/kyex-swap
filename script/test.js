const { ethers, upgrades, network } = require("hardhat");
const { FeeData } = require("ethers");
const feedData = ethers.provider.getFeeData();

async function approveAndSwap() {
  const KYEXSwapBscV1 = await ethers.getContractAt(
    "KYEXSwapBscV1",
    "0x9cC2bFE2d2C5ae9D427CC7961F67E66Bb782Fb2A"
  );
  // const maxFeePerGas = await feedData.maxFeePerGas();
  // const maxPriorityFeePerGas = await feedData.maxPriorityFeePerGas();
  const provider = new ethers.JsonRpcProvider(
    "https://bsc-testnet.g.allthatnode.com/full/evm/e6f4078993be427386b109445e004b31"
  );
  const feeData = await provider.getFeeData();
  console.log(feeData);
  const tx2 = await KYEXSwapBscV1.onReceiveSwap(
    "0xFa60D973F7642B748046464e165A65B7323b0DEE",
    "0x670f4f034B5e9B01580F888741d129866bBB2cC3",
    ethers.parseUnits("0.2", 18),
    feeData.gasPrice * BigInt(300000),
    "0xe34d701947f33dfd3253c58f39f67ac5e3a51281a833963d0c9e4827a7e17915"
  );
  console.log(tx2);
  // const tx2 = await KYEXSwapBscV1.withdrawZETA();
}

approveAndSwap();
// checkOwner();