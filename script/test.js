const { ethers, upgrades, network } = require("hardhat");
const { AbiCoder } = require("ethers");
const abiCoder = new AbiCoder();

async function approveAndSwap() {
  const GatewayEVM = await ethers.getContractAt(
    "IGatewayZEVM",
    "0x6c533f7fE93fAE114d0954697069Df33C9B74fD7"
  );
  // ETH.usdc ==> BSC.BNB 0xe016627238f9d9b224fc895958d68aef690bb69be6cfbdfca5f4daa8047c69bd
  // const ERC20 = await ethers.getContractAt(
  //   "ERC20",
  //   "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"
  // );
  // await ERC20.approve(
  //   "0x0c487a766110c85d301d96e33579c5b317fa4995",
  //   ethers.parseUnits("1", 6)
  // );
  // const message = abiCoder.encode(
  //   ["bool", "uint256", "address", "address", "uint256", "bytes"],
  //   [
  //     true,
  //     0,
  //     "0xd97b1de3619ed2c6beb3860147e30ca8a7dc9891",
  //     "0x7538c60F736966963933F78b2Fc74e9F2550D522",
  //     97,
  //     ethers.toUtf8Bytes("hello"),
  //   ]
  // );
  // const revertOptions = {
  //   revertAddress: ethers.ZeroAddress,
  //   callOnRevert: "false",
  //   abortAddress: ethers.ZeroAddress,
  //   revertMessage: "0x",
  //   onRevertGasLimit: 0,
  // };

  // const tx = await GatewayEVM.depositAndCall(
  //   "0x9cC2bFE2d2C5ae9D427CC7961F67E66Bb782Fb2A",
  //   ethers.parseUnits("1", 6),
  //   "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
  //   message,
  //   revertOptions
  // );
  // console.log(tx);

  //ETH.eth ==> BSC.BNB  0x66bcf866f2983a22adf858a2ef1a334f11060500efc26f1c2a761e544689de6e
  const recipient = ethers.hexlify(
    "0x7f0c0fB10FA8FA3A40E2F8BCc7A5C5508D1b3dB8"
  );

  const message = abiCoder.encode(
    ["bool", "uint256", "address", "bytes", "uint256", "bytes"],
    [
      false,
      0,
      "0xcC683A782f4B30c138787CB5576a86AF66fdc31d",
      recipient,
      97,
      ethers.toUtf8Bytes("hello"),
    ]
  );

  const revertOptions = {
    revertAddress: ethers.ZeroAddress,
    callOnRevert: "false",
    abortAddress: ethers.ZeroAddress,
    revertMessage: "0x",
    onRevertGasLimit: 0,
  };

  const callOptions = {
    gasLimit: 10000,
    isArbitraryCall: false,
  };

  const tx = await GatewayEVM[
    "withdrawAndCall(bytes,uint256,address,bytes,(uint256,bool),(address,bool,address,bytes,uint256))"
  ](
    recipient,
    ethers.parseEther("0.1"),
    "0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891",
    message,
    callOptions,
    revertOptions
  );
  console.log(tx);
  // const tx = await GatewayEVM.deposit(
  //   "0x801a3180A319789375dFc7871199BfEA89dCde1a",
  //   revertOptions,
  //   { value: ethers.parseEther("0.1") }
  // );
  // console.log(tx);

  // ETH.usdc ==> zeta.usdc
  // const ERC20 = await ethers.getContractAt(
  //   "ERC20",
  //   "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"
  // );
  // await ERC20.approve(
  //   "0x0c487a766110c85d301d96e33579c5b317fa4995",
  //   ethers.parseUnits("1", 6)
  // );
  // const revertOptions = {
  //   revertAddress: ethers.ZeroAddress,
  //   callOnRevert: "false",
  //   abortAddress: ethers.ZeroAddress,
  //   revertMessage: "0x",
  //   onRevertGasLimit: 0,
  // };

  // const recipient = ethers.hexlify(
  //   "0x670f4f034B5e9B01580F888741d129866bBB2cC3"
  // );
  // const message = abiCoder.encode(
  //   ["bool", "uint256", "address", "bytes", "uint256", "bytes"],
  //   [
  //     false,
  //     0,
  //     "0x05BA149A7bd6dC1F937fA9046A9e05C05f3b18b0",
  //     recipient,
  //     97,
  //     ethers.toUtf8Bytes("hello"),
  //   ]
  // );
  // const tx = await GatewayEVM.depositAndCall(
  //   "0x9cC2bFE2d2C5ae9D427CC7961F67E66Bb782Fb2A",
  //   ethers.parseUnits("1", 6),
  //   "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
  //   message,
  //   revertOptions
  // );
  // console.log(tx);
}

approveAndSwap();
// checkOwner();
