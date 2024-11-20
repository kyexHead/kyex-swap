// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library Events {
    event SwapExecuted(
        address indexed sender,
        address indexed recipient,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    event onCallExecuted(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed recipient
    );
    event ReceivedToken(
        address indexed sender,
        address indexed token,
        uint256 amount
    );
    event TokenTransfer(
        bool isCrossChain,
        address token,
        address receiver,
        address gasZRC20,
        uint256 gasFee,
        uint256 amount,
        uint256 chainId
    );
    event WithdrawnNativeToken(address indexed owner, uint256 amount);
    event Withdrawn(
        address indexed owner,
        address indexed tokenAddress,
        uint256 amount
    );
    event ReceivePlatformFee(
        address indexed token,
        address indexed sender,
        address receiver,
        uint256 amount
    );
}
