# KYEX Swap 01

## Project Overview

KYEX is a decentralized platform facilitating token swaps and cross-chain transfers, leveraging ZetaChain for bridging assets between different blockchains. It implements a platform fee mechanism, where a portion of each swap is allocated to a designated treasury.

## Contract: `KYEXSwap01`

This contract is the core of the KYEX platform, handling:

* **Token Swaps:** Enables users to swap tokens within the ZetaChain ecosystem.
* **Cross-Chain Swaps:** Facilitates swaps between ZetaChain and other networks like Ethereum or Bitcoin.
* **Wrapped ZETA (WZETA) Handling:** Supports wrapping and unwrapping of WZETA tokens.
* **Administrative Functions:** Provides functions for the contract owner to update crucial parameters such as the treasury address, platform fee, and slippage tolerance. 

## Critical Functionalities

### `zrcSwapToNative`

**Purpose:** Swap tokens from ZetaChain to a native token on another chain or to a ZetaChain-based token.

**Input Parameters:**

* `tokenInOfZetaChain`: The address of the token on ZetaChain being swapped (WZETA or a ZRC20 token).
* `tokenOutOfZetaChain`: The address of the desired output token on the target chain.
* `amountIn`: The amount of `tokenInOfZetaChain` to swap.
* `isWrap`: `true` if the input token is tZETA and needs to be wrapped; `false` for WZETA.
* `btcRecipient`: The Bitcoin address to receive BTC (only relevant when swapping to Bitcoin).
* `slippageTolerance`: The maximum acceptable slippage percentage for the swap.
* `isCrossChain`: `true` for cross-chain swaps; `false` for swaps within ZetaChain.

**Expected Output:**

* Executes the swap, potentially involving cross-chain transfers and Uniswap swaps.
* Emits a `SwapExecuted` event containing swap details.

**Business Logic:**

1. Identifies the appropriate gas token (`gasZRC20`) for the target chain.
2. Handles wrapping of tZETA if necessary.
3. Performs the required swaps and cross-chain transfers as per the input parameters.
4. Calculates and deducts the platform fee, transferring it to the treasury.
5. Withdraws the final output token to the user's address (or the specified Bitcoin address for BTC swaps).

### `swapTokens`

**Purpose:** Swap tokens within the ZetaChain ecosystem, potentially using Uniswap V2 if a direct pair isn't available.

**Input Parameters:**

* `tokenA`: The address of the input token.
* `tokenB`: The address of the desired output token.
* `amountA`: The amount of `tokenA` to swap.
* `isWrap`: `true` if the input token is tZETA and needs to be wrapped; `false` for WZETA.
* `slippageTolerance`: The maximum acceptable slippage percentage for the swap.

**Expected Output:**

* Executes the swap.
* Returns the amount of `tokenB` received after the swap and fee deduction.
* Emits a `PerformSwap` event with swap details.

**Business Logic:**

1. Handles wrapping of tZETA if needed.
2. Checks if a direct pair exists on Uniswap for the tokens.
3. Performs a single swap if a direct pair exists, otherwise, performs a two-step swap via WZETA.
4. Calculates and deducts the platform fee.

### `withdrawBTC`, `withdrawToken`, `transferZETA`, `transferZRC`

**Purpose:** These functions handle the final withdrawal or transfer of tokens to the user's address after a swap.

**Interactions:**

* Interact with the corresponding token contracts to execute transfers.
* Emit `TokenTransfer` or `ZETAWrapped` events.

## External Dependencies

* **Uniswap V2:** `IUniswapV2Router02`, `IUniswapV2Factory` interfaces for on-chain swaps.
* **ZetaChain:** `IZRC20`, `IWZETA` interfaces for interacting with ZRC20 tokens and WZETA.
* **OpenZeppelin:** `UUPSUpgradeable`, `OwnableUpgradeable` for contract upgradability and ownership control.
* **Custom Library:** `TransferHelper` for secure token transfers.

## Deployment Process

1. **Compile Contracts:** Compile all Solidity contracts.
2. **Deploy & Initialize:** 
   * Using Hardhat's `@openzeppelin/hardhat-upgrades` plugin, deploy the UUPS proxy contract. 
   * Initialize the contract's state variables and set the owner by calling the `initialize` function. 
3. **Set up Access Control:** Transfer contract ownership to the appropriate address or multi-sig wallet.


## ---------------------------------------------------------------

# KYEX Swap 02 

## 1. Contracts Under the Scope of Audit

* `KYEXSwap02`

## 2. Project Description

KYEXSwap02 appears to be the core contract for the KYEX project, facilitating cross-chain token swaps, potentially leveraging ZetaChain for interoperability. It empowers users to swap tokens between different chains and provides functionalities for wrapping, unwrapping, and withdrawing various tokens, including ZETA and its wrapped counterpart, WZETA.

## 3. Short Description of the Contract

* **`KYEXSwap02`**
    * Enables cross-chain token swaps, likely utilizing ZetaChain for bridging.
    * Utilizes Uniswap V2 for on-chain swaps on the connected chain.
    * Supports wrapping and unwrapping of ZETA (the native token) into WZETA (Wrapped ZETA).
    * Implements a platform fee mechanism, collecting a portion of each swap and directing it to a treasury.
    * Includes administrative functions for the owner to update key parameters (treasury address, platform fee, slippage tolerance, etc.).

## 4. List of Critical Functionalities

* **`onCrossChainCall`**
    * **Input Parameters:**
        * `context`: ZetaChain context data.
        * `zrc20`: Address of the ZRC20 token being swapped.
        * `amount`: Amount of the ZRC20 token.
        * `message`: Encoded message containing swap details 
            * `isWithdraw`
            * `slippage`
            * `targetTokenAddress`
            * `sameNetworkAddress`
            * `recipientAddress`
    * **Expected Output:**
        * Executes the appropriate swap or transfer operation based on the message data.
        * Emits `SwapExecuted` and potentially other events.
    * **Business Logic:**
        * Decodes the message to extract swap parameters.
        * Handles scenarios based on `isWithdraw` value:
            * `0`: Same-network swap
            * `1`: Wrap and transfer (for WZETA)
            * `2`: Unwrap and transfer (for WZETA)
            * `3`: Transfer ERC20 token
            * `4`: Deposit ZRC20 token
        * Calculates and deducts platform fees.
        * Interacts with Uniswap, ZRC20 contracts, and potentially ZetaChain's system contract.

* **`calculateSwapAmounts`**
    * **Input Parameters:**
        * `zrc20`: Address of the input ZRC20 token.
        * `targetTokenAddress`: Address of the desired output token.
        * `newAmount`: Amount to be swapped.
        * `slippage`: Allowed slippage tolerance.
    * **Expected Output:**
        * Returns a `SwapAmounts` struct with details about: 
            * the required gas token
            * gas fee
            * output amount
            * target token status
    * **Business Logic:**
        * Determines if the target token is WZETA.
        * Calculates gas fee and required input amount (if not WZETA).
        * Calculates the expected output amount.

* **`swapExactTokensForTokens`, `swapTokensForExactTokens` (in `SwapHelperLib`)**
    * These functions likely interact with Uniswap V2 to perform token swaps, considering slippage tolerance.

* **Various `withdraw` and `transfer` functions**
    * Handle the final withdrawal or transfer of tokens to the recipient's address after a swap.

## 5. External Dependencies

* `@openzeppelin/contracts/proxy/utils/UUPSUpgradeable`
* `@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable`
* `SwapHelperLib`
* `TransferHelper`
* `BytesHelperLib`
* `IWZETA` 
* `Errors` 
* `UniswapV2Library`
* `SystemContract`

## 6. Deployment Process (High-Level)

1. **Compile Contracts**
2. **Deploy & Initialize:** Deploy UUPS proxy contract and initialize it using the `initialize` function.
3. **Set up Access Control:** Transfer ownership.


