// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "libraries/SwapHelperLib.sol";
import "libraries/TransferHelper.sol";
import "libraries/BytesHelperLib.sol";
import "libraries/zetaV2/interfaces/IWZETA.sol";
import "libraries/error/Errors.sol";

contract KYEXSwap02 is zContract, UUPSUpgradeable, OwnableUpgradeable {
    ///////////////////
    // Struct
    ///////////////////
    struct SwapAmounts {
        uint256 inputForGas;
        address gasZRC20;
        uint256 gasFee;
        uint256 outputAmount;
        bool isTargetZeta;
        address wzeta;
    }

    ///////////////////
    // State Variables
    ///////////////////
    uint16 public constant BITCOIN = 18332;
    address private WZETA; // Note:when deploying on the mainnet，This should be changed to 【 address public constant WZETA = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf; 】
    address private UniswapRouter;
    address private UniswapFactory;
    address private kyexTreasury;
    uint32 private MAX_DEADLINE;
    uint16 private platformFee;
    uint16 private MAX_SLIPPAGE;
    SystemContract private systemContract;

    ///////////////////
    // Events
    ///////////////////
    event TreasuryAddressUpdated(address newAddress);
    event PlatformFeeUpdated(uint16 newFee);
    event PlatformFeeSent(uint256 amount, address zrc20);
    event MaxSlippageUpdated(uint16 slippage);
    event SwapExecuted(uint256 amount, address targetTokenAddress, address recipient);
    event WrappedTokenTransfer(uint256 outputAmount, address recipient);
    event UnWrapZetaTokenTransfer(uint256 outputAmount, address recipient);
    event TokenWithdrawal(uint256 outputAmount, bytes recipient);
    event DebugInfo(
        string message,
        address targetTokenAddress,
        address recipientAddress,
        uint256 gasFee,
        uint256 inputForGas,
        uint256 outputAmount
    );
    event ZETAWithdrawn(address indexed owner, uint256 amount);
    event TokenWithdrawn(address indexed token, address indexed treasury, uint256 amount);
    event MaxDeadLineUpdated(uint32 maxDeadLine);
    event systemContractUpdated(address newAddress);

    ///////////////////
    // Modifiers
    ///////////////////
    modifier onlySystem(SystemContract _systemContract) {
        if (msg.sender != address(_systemContract)) {
            revert Errors.OnlySystemContract();
        }
        _;
    }

    ///////////////////
    // Initialize Function
    ///////////////////
    function initialize(
        address _WZETA, //Note: when deploying on the mainnet，this line should be deleted.
        address _UniswapRouter,
        address _UniswapFactory,
        address _kyexTreasury,
        uint32 _MAX_DEADLINE,
        uint16 _platformFee,
        uint16 _MAX_SLIPPAGE,
        address _systemContract
    ) external initializer {
        __Ownable_init();

        WZETA = _WZETA; //Note: when deploying on the mainnet，this line should be deleted.
        UniswapRouter = _UniswapRouter;
        UniswapFactory = _UniswapFactory;
        kyexTreasury = _kyexTreasury;
        MAX_DEADLINE = _MAX_DEADLINE;
        platformFee = _platformFee;
        MAX_SLIPPAGE = _MAX_SLIPPAGE;
        systemContract = SystemContract(_systemContract);
    }

    ///////////////////
    // Public Function
    ///////////////////
    //Note: when deploying on the mainnet, this function should be deleted.
    function getZETA() public view returns (address) {
        return WZETA;
    }

    function getUniswapRouter() public view returns (address) {
        return UniswapRouter;
    }

    function getUniswapFactory() public view returns (address) {
        return UniswapFactory;
    }

    function getTreasuryAddress() public view returns (address) {
        return kyexTreasury;
    }

    function getPlatformFee() public view returns (uint16) {
        return platformFee;
    }

    function getMaxDeadLine() public view returns (uint32) {
        return MAX_DEADLINE;
    }

    function getMaxSlippage() public view returns (uint16) {
        return MAX_SLIPPAGE;
    }

    function getSystemContract() public view returns (address) {
        return address(systemContract);
    }

    ///////////////////
    // External Function
    ///////////////////
    function withdrawZETA() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert Errors.InsufficientFunds();
        (bool success,) = owner().call{value: balance}("");
        if (!success) revert Errors.TransferFailed();
        emit ZETAWithdrawn(owner(), balance);
    }

    function withdrawZRCToken(address tokenAddress, address recipient) external onlyOwner {
        uint256 balance = IZRC20(tokenAddress).balanceOf(address(this));
        if (balance == 0) revert Errors.InsufficientFunds();

        IZRC20(tokenAddress).transfer(recipient, balance);
        emit TokenWithdrawn(tokenAddress, recipient, balance);
    }

    function onCrossChainCall(zContext calldata context, address zrc20, uint256 amount, bytes calldata message)
        external
        override
        onlySystem(systemContract)
    {
        (
            uint32 isWithdraw,
            uint32 slippage,
            address targetTokenAddress,
            address sameNetworkAddress,
            bytes memory recipientAddress
        ) = decodeMessage(message, context.chainID);

        if (isWithdraw == 0) {
            sameNetworkSwap(zrc20, sameNetworkAddress, amount, recipientAddress, slippage);
        } else if (isWithdraw == 3) {
            transferERC20(zrc20, targetTokenAddress, amount, recipientAddress, slippage);
        } else {
            (SwapAmounts memory swapAmounts) = calculateSwapAmounts(zrc20, targetTokenAddress, amount, slippage);

            uint256 feeAmount = swapAmounts.outputAmount * platformFee / 10000;
            uint256 newAmount = swapAmounts.outputAmount - feeAmount;

            TransferHelper.safeTransfer(targetTokenAddress, kyexTreasury, feeAmount);

            address recipient = address(uint160(bytes20(recipientAddress)));
            if (swapAmounts.isTargetZeta) {
                if (isWithdraw == 1) {
                    wrapAndTransfer(swapAmounts.wzeta, newAmount, recipient);
                } else if (isWithdraw == 2) {
                    unWrapAndTransfer(swapAmounts.wzeta, newAmount, recipient);
                }
            } else {
                if (isWithdraw == 1) {
                    transferZRC20(targetTokenAddress, newAmount, recipient);
                } else if (isWithdraw == 2) {
                    withdrawZRC(
                        swapAmounts.gasZRC20, swapAmounts.gasFee, targetTokenAddress, newAmount, recipientAddress
                    );
                }
            }

            emit SwapExecuted(newAmount, targetTokenAddress, address(uint160(bytes20(recipientAddress))));
            emit DebugInfo(
                "Swapped",
                targetTokenAddress,
                bytesToAddress(recipientAddress, 0),
                swapAmounts.gasFee,
                swapAmounts.inputForGas,
                newAmount
            );
        }
    }

    function updateTreasuryAddress(address _newAddress) external onlyOwner {
        kyexTreasury = _newAddress;
        emit TreasuryAddressUpdated(_newAddress);
    }

    function updatePlatformFee(uint16 _newFee) external onlyOwner {
        platformFee = _newFee;
        emit PlatformFeeUpdated(_newFee);
    }

    function updateSlippage(uint16 _slippage) external onlyOwner {
        MAX_SLIPPAGE = _slippage;
        emit MaxSlippageUpdated(_slippage);
    }

    function updateMaxDeadLine(uint32 _maxDeadLine) external onlyOwner {
        MAX_DEADLINE = _maxDeadLine;
        emit MaxDeadLineUpdated(_maxDeadLine);
    }

    function updateSystemContract(address _systemContract) external onlyOwner {
        systemContract = SystemContract(_systemContract);
        emit systemContractUpdated(_systemContract);
    }

    function updateUniswap(address _uniswapRouter, address _uniswapFactory) external onlyOwner {
        UniswapRouter = _uniswapRouter;
        UniswapFactory = _uniswapFactory;
    }

    ///////////////////
    // Internal Function
    ///////////////////
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function wrapAndTransfer(address wzeta, uint256 amount, address recipient) internal {
        IWETH9(wzeta).transfer(recipient, amount);
        emit WrappedTokenTransfer(amount, recipient);
    }

    function unWrapAndTransfer(address wzeta, uint256 amount, address recipient) internal {
        // Unwrap wZETA to tZETA
        IWETH9(wzeta).withdraw(amount);
        // Transfer tZETA to recipient
        payable(recipient).transfer(amount);

        // Emit event for unwrapped transfer
        emit UnWrapZetaTokenTransfer(amount, recipient);
    }

    function withdrawZRC(
        address gasZRC,
        uint256 gas,
        address tokenAddress,
        uint256 amount,
        bytes memory recipientAddress
    ) internal {
        IZRC20(gasZRC).approve(tokenAddress, gas);
        IZRC20(tokenAddress).withdraw(recipientAddress, amount);
        emit TokenWithdrawal(amount, recipientAddress);
    }

    function withdrawBTC(address token, bytes memory recipient, uint256 amount) internal {
        (address gasZRC20, uint256 gasFee) = IZRC20(token).withdrawGasFee();
        if (IZRC20(gasZRC20).balanceOf(address(this)) < gasFee) revert Errors.InsufficientGasForWithdraw();

        IZRC20(gasZRC20).approve(token, gasFee);
        IZRC20(token).withdraw(recipient, amount - gasFee);

        emit TokenWithdrawal(amount, recipient);
    }

    function transferZRC20(address tokenAddress, uint256 amount, address recipient) internal {
        (address gasZRC20, uint256 gasFee) = IZRC20(tokenAddress).withdrawGasFee();
        IZRC20(gasZRC20).approve(tokenAddress, gasFee);
        IZRC20 token = IZRC20(tokenAddress);
        token.transfer(recipient, amount);
        emit WrappedTokenTransfer(amount, recipient);
    }

    function transferERC20(
        address zrc20,
        address targetTokenAddress,
        uint256 amount,
        bytes memory recipientAddress,
        uint32 slippage
    ) internal {
        uint256 outputAmount =
            SwapHelperLib.swapExactTokensForTokens(systemContract, zrc20, amount, targetTokenAddress, 0, slippage);
        if (outputAmount == 0) revert Errors.SwapFailed();
        if (!IZRC20(targetTokenAddress).approve(targetTokenAddress, outputAmount)) revert Errors.ApprovalFailed();

        uint256 feeAmount = outputAmount * platformFee / 10000;
        uint256 newAmount = outputAmount - feeAmount;

        TransferHelper.safeTransfer(targetTokenAddress, kyexTreasury, feeAmount);

        bool transferSuccess = IZRC20(targetTokenAddress).transfer(bytesToAddress(recipientAddress, 0), newAmount);
        if (!transferSuccess) revert Errors.TransferFailed();

        emit WrappedTokenTransfer(amount, address(uint160(bytes20(recipientAddress))));
    }

    function sameNetworkSwap(
        address zrc20,
        address sameNetworkTokenAddress,
        uint256 amount,
        bytes memory recipientAddress,
        uint32 slippage
    ) internal {
        if (amount == 0) revert Errors.NeedsMoreThanZero();
        if (slippage > MAX_SLIPPAGE) revert Errors.SlippageToleranceExceedsMaximum();

        (address gasZRC20, uint256 gasFee) = IZRC20(sameNetworkTokenAddress).withdrawGasFee();
        // swap WZETA
        uint256 outputAmount = SwapHelperLib.swapExactTokensForTokens(systemContract, zrc20, amount, WZETA, 0, slippage);
        uint256 inputForGas =
            SwapHelperLib.swapTokensForExactTokens(systemContract, WZETA, gasFee, gasZRC20, outputAmount, slippage);
        uint256 remainingAmount = IWETH9(WZETA).balanceOf(address(this));
        if (inputForGas == 0) revert Errors.SwapFailed();

        uint256 finalAmount = SwapHelperLib.swapExactTokensForTokens(
            systemContract, WZETA, remainingAmount, sameNetworkTokenAddress, 0, slippage
        );
        // uint256 feeAmount = finalAmount.mul(platformFee).div(10000);
        // uint256 newAmount = finalAmount.sub(feeAmount);

        // TransferHelper.safeTransfer(sameNetworkTokenAddress, kyexTreasury, feeAmount);

        IZRC20(gasZRC20).approve(sameNetworkTokenAddress, gasFee);
        IZRC20(sameNetworkTokenAddress).withdraw(recipientAddress, finalAmount);

        emit TokenWithdrawal(amount, recipientAddress);
    }

    function bytesToAddress(bytes memory data, uint256 offset) internal pure returns (address output) {
        bytes memory b = new bytes(20);
        for (uint256 i = 0; i < 20; i++) {
            b[i] = data[i + offset];
        }
        assembly {
            output := mload(add(b, 20))
        }
    }

    function decodeMessage(bytes calldata message, uint256 chainID)
        internal
        pure
        returns (
            uint32 isWithdraw,
            uint32 slippage,
            address targetTokenAddress,
            address sameNetworkTokenAddress,
            bytes memory recipientAddress
        )
    {
        if (chainID == BITCOIN) {
            isWithdraw = BytesHelperLib.bytesToUint32(message, 3);
            slippage = BytesHelperLib.bytesToUint32(message, 7);
            targetTokenAddress = BytesHelperLib.bytesToAddress(message, 8);
            sameNetworkTokenAddress = BytesHelperLib.bytesToAddress(message, 28);
            recipientAddress = abi.encodePacked(BytesHelperLib.bytesToAddress(message, 48));
        } else {
            (
                uint32 _isWithdraw,
                uint32 _slippage,
                address targetToken,
                address sameNetworkToken,
                bytes memory recipient
            ) = abi.decode(message, (uint32, uint32, address, address, bytes));
            targetTokenAddress = targetToken;
            sameNetworkTokenAddress = sameNetworkToken;
            recipientAddress = recipient;
            isWithdraw = _isWithdraw;
            slippage = _slippage;
        }
    }

    function calculateSwapAmounts(address zrc20, address targetTokenAddress, uint256 newAmount, uint32 slippage)
        internal
        returns (SwapAmounts memory swapAmounts)
    {
        swapAmounts.wzeta = systemContract.wZetaContractAddress();
        swapAmounts.isTargetZeta = targetTokenAddress == swapAmounts.wzeta;
        if (!swapAmounts.isTargetZeta) {
            (swapAmounts.gasZRC20, swapAmounts.gasFee) = IZRC20(targetTokenAddress).withdrawGasFee();
            swapAmounts.inputForGas = SwapHelperLib.swapTokensForExactTokens(
                systemContract, zrc20, swapAmounts.gasFee, swapAmounts.gasZRC20, newAmount, slippage
            );
        }
        swapAmounts.outputAmount = SwapHelperLib.swapExactTokensForTokens(
            systemContract,
            zrc20,
            swapAmounts.isTargetZeta ? newAmount : newAmount - swapAmounts.inputForGas,
            targetTokenAddress,
            0,
            slippage
        );
    }

    ///////////////////
    // receive
    ///////////////////
    receive() external payable {}
}
