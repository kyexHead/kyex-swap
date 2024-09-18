async function createUniswapPair(
  deployerAddr,
  UniswapRouter,
  UniswapFactory,
  tokenA,
  tokenB
) {
  const tokenAaddr = await tokenA.getAddress();
  const tokenBaddr = await tokenB.getAddress();
  await UniswapFactory.createPair(tokenAaddr, tokenBaddr);

  const LPAmount = ethers.parseUnits("500", 18);
  const UniswapRouterAddr = await UniswapRouter.getAddress();

  await tokenA.approve(UniswapRouterAddr, LPAmount);
  await tokenB.approve(UniswapRouterAddr, LPAmount);

  await UniswapRouter.addLiquidity(
    tokenAaddr,
    tokenBaddr,
    LPAmount,
    LPAmount,
    0,
    0,
    deployerAddr,
    Math.floor(Date.now() / 1000) + 60 * 10
  );
}

module.exports = { createUniswapPair };
