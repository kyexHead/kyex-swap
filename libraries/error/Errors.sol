// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library Errors {
    error SwapFailed();
    error ApprovalFailed();
    error TransferFailed();
    error InsufficientFunds();
    error InsufficientGasForWithdraw();
    error NeedsMoreThanZero();
    error OnlyGateWay();
    error OnlySupportZETA();
    error InsufficientAllowance();
    error SlippageToleranceExceedsMaximum();
    error PlatformFeeNeedslessThanOneHundredPercent();
    error IncorrectAmountSent();
    error ErrorTransferringZeta();
    error ChainIdAlreadyEnabled();
    error ChainIdNotAvailable();
    error InvalidZetaValueAndGas();
}
