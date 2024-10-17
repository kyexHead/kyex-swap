# KYEX Swap 01

## Project Overview

KYEXSwapV1 is a decentralized exchange (DEX) built on ZetaChain. It facilitates token swaps both within the ZetaChain ecosystem and cross-chain to other networks. The contract leverages Uniswap V2 for liquidity and pricing, and ZetaChain's infrastructure for cross-chain message passing and asset transfer.

## Decentralized Token Swaps on ZetaChain

This repository contains the `KYEXSwapV1.sol` contract, a decentralized exchange (DEX) built on ZetaChain. It enables users to swap tokens both within the ZetaChain ecosystem and cross-chain to other networks.

## Contract Overview

`KYEXSwapV1.sol` is the core contract of the KYEXSwapV1 DEX. It handles the following functionalities:

* **Token Swaps:** Facilitates token swaps using Uniswap V2 liquidity pools.
* **Cross-Chain Transfers:** Leverages ZetaChain's infrastructure for secure cross-chain token transfers.
* **Fee Management:** Calculates and distributes platform fees.
* **Security:** Implements security measures like pausing functionality and reentrancy guards.

## Core Functionalities

### `swapFromZetaChainToAny`

This function allows users to swap tokens from ZetaChain to a native token on another chain or to a ZetaChain-based token.

**Parameters:**

* `tokenInOfZetaChain`: Address of the token on ZetaChain being swapped.
* `tokenOutOfZetaChain`: Address of the desired output token.
* `amountIn`: Amount of `tokenInOfZetaChain` to swap.
* `btcRecipient`: Bitcoin address (if applicable).
* `minAmountOut`: Minimum acceptable output amount.
* `isCrossChain`: Boolean indicating cross-chain or on-chain swap.
* `chainId`: Target chain ID (if applicable).

**Logic:**

1. Receives user tokens.
2. Calculates the output amount based on Uniswap liquidity and fees.
3. If cross-chain, interacts with ZetaChain's connector contract to initiate the transfer.
4. Sends the swapped tokens to the user on the destination chain.

### `onCrossChainCall`

This function enables cross-chain token swaps initiated from another chain.

**Parameters:**

* `context`: ZetaChain cross-chain message context.
* `tokenInOfZetaChain`: Address of the input token on ZetaChain.
* `amountIn`: Amount of `tokenInOfZetaChain`.
* `message`: Encoded swap details.

**Logic:**

1. Decodes the swap details from the message.
2. Calculates the output amount.
3. Interacts with ZetaChain's connector to finalize the cross-chain transfer.
4. Sends the swapped tokens to the recipient on ZetaChain.

### `withdrawZETA` and `withdrawZRC20`

These functions allow the contract owner to withdraw ZETA or ZRC20 tokens from the contract.

**Parameters:**

* `withdrawZETA`: No parameters.
* `withdrawZRC20`: `zrc20Address` - Address of the ZRC20 token to withdraw.

**Logic:**

1. Checks the contract's token balance.
2. Transfers the balance to the owner's address.

## External Dependencies

* **Uniswap V2:** `IUniswapV2Router02`, `IUniswapV2Factory`
* **ZetaChain:** `IWZETA`, `SystemContract`, `zContract`, `ZetaInterfaces`, `ZetaConnector`
* **OpenZeppelin:** `UUPSUpgradeable`, `OwnableUpgradeable`, `PausableUpgradeable`, `ReentrancyGuardUpgradeable`
* **Other Libraries:** `TransferHelper`, `Errors`

## Deployment

The contract should be deployed on the ZetaChain network. The `initialize` function needs to be called after deployment to set the initial parameters.

## Security Considerations

* The contract uses the UUPS upgradeable pattern, allowing for future upgrades.
* Pausing functionality is implemented to halt trading in case of emergencies.
* Reentrancy guards prevent reentrancy attacks.

## License

This contract is licensed under the MIT License.