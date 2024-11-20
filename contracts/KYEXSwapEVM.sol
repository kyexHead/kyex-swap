// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import "libraries/TransferHelper.sol";
import "libraries/error/Errors.sol";
import "libraries/event/Events.sol";
import "libraries/IWETH.sol";
import "libraries/zetaV2/contracts/evm/interfaces/IGatewayEVM.sol";

/*
██╗░░██╗██╗░░░██╗███████╗██╗░░██╗
██║░██╔╝╚██╗░██╔╝██╔════╝╚██╗██╔╝
█████═╝░░╚████╔╝░█████╗░░░╚███╔╝░
██╔═██╗░░░╚██╔╝░░██╔══╝░░░██╔██╗░
██║░╚██╗░░░██║░░░███████╗██╔╝╚██╗
╚═╝░░╚═╝░░░╚═╝░░░╚══════╝╚═╝░░╚═╝

░█████╗░██████╗░░█████╗░░██████╗░██████╗░░░░░░░█████╗░██╗░░██╗░█████╗░██╗███╗░░██╗
██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔════╝░░░░░░██╔══██╗██║░░██║██╔══██╗██║████╗░██║
██║░░╚═╝██████╔╝██║░░██║╚█████╗░╚█████╗░█████╗██║░░╚═╝███████║███████║██║██╔██╗██║
██║░░██╗██╔══██╗██║░░██║░╚═══██╗░╚═══██╗╚════╝██║░░██╗██╔══██║██╔══██║██║██║╚████║
╚█████╔╝██║░░██║╚█████╔╝██████╔╝██████╔╝░░░░░░╚█████╔╝██║░░██║██║░░██║██║██║░╚███║
░╚════╝░╚═╝░░╚═╝░╚════╝░╚═════╝░╚═════╝░░░░░░░░╚════╝░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝╚═╝░░╚══╝

░██████╗░██╗░░░░░░░██╗░█████╗░██████╗░
██╔════╝░██║░░██╗░░██║██╔══██╗██╔══██╗
╚█████╗░░╚██╗████╗██╔╝███████║██████╔╝
░╚═══██╗░░████╔═████║░██╔══██║██╔═══╝░
██████╔╝░░╚██╔╝░╚██╔╝░██║░░██║██║░░░░░
╚═════╝░░░░╚═╝░░░╚═╝░░╚═╝░░╚═╝╚═╝░░░░░
*/

/**
 * @title KYEX CrossChain Swap
 * @author KYEX-TEAM
 * @dev KYEX Mainnet ZETACHAIN Smart Contract V1
 */
contract KYEXSwapEVM is
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    ///////////////////
    // Struct
    ///////////////////
    struct SwapDetail {
        address[] sourceChainSwapPath;
        address[] zetaChainSwapPath;
        address[] targetChainSwapPath;
        address[] gasZRC20SwapPath;
        address recipient;
        uint256 gasFee;
        bytes omnichainSwapContract;
        uint256 chainId;
    }

    ///////////////////
    // State Variables
    ///////////////////
    //TODO: Change it before deployment
    address private constant uniswapRouter =
        0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;
    address private constant uniswapQuoter =
        0xEd1f6473345F45b75F8179591dd5bA1888cf2FB3;
    address private constant gateWay =
        0x0c487a766110c85d301D96E33579C5B317Fa4995;
    address private constant universalContract =
        0x0c487a766110c85d301D96E33579C5B317Fa4995;
    address private constant nativeToken =
        0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;

    address public kyexTreasury;
    uint32 public maxDeadLine;
    uint16 public crossChainPlatformFee;
    uint16 public sourceChainPlatformFee;
    uint256 public volume;

    ///////////////////
    // Initialize Function
    ///////////////////

    /**
     * @notice To Iinitialize contract after deployed.
     */
    function initialize() external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    ///////////////////
    // Public Function
    ///////////////////

    /**
     * @dev Pause contract trading（only owner）
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev unpause contract trading（only owner）
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    ///////////////////
    // External Function
    ///////////////////

    /**
     * @dev update config
     */
    function updateConfig(
        address _kyexTreasury,
        uint32 _maxDeadLine,
        uint16 _crossChainPlatformFee,
        uint16 _sourceChainPlatformFee
    ) external onlyOwner {
        kyexTreasury = _kyexTreasury;
        maxDeadLine = _maxDeadLine;
        crossChainPlatformFee = _crossChainPlatformFee;
        sourceChainPlatformFee = _sourceChainPlatformFee;
    }

    /**
     * @dev Withdraw Native Token from the contract, only the owner can execute this operation
     */
    function withdrawNativeToken() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert Errors.InsufficientFunds();
        TransferHelper.transferNativeToken(owner(), balance);

        emit Events.WithdrawnNativeToken(owner(), balance);
    }

    /**
     * @dev Withdraw ERC20 from the contract, only the owner can execute this operation
     */
    function withdrawERC20(address tokenAddress) external onlyOwner {
        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
        if (balance == 0) revert Errors.InsufficientFunds();
        TransferHelper.safeTransfer(tokenAddress, owner(), balance);

        emit Events.Withdrawn(owner(), tokenAddress, balance);
    }

    function swap(
        uint256 amountIn,
        SwapDetail calldata swapDetail
    ) external payable whenNotPaused nonReentrant {
        uint256 sourcePathLength = swapDetail.sourceChainSwapPath.length;
        uint256 zetaPathLength = swapDetail.zetaChainSwapPath.length;
        uint256 targetPathLength = swapDetail.targetChainSwapPath.length;
        address tokenInOfSourceChain = swapDetail.sourceChainSwapPath[0];
        address tokenOutOfSourceChain = swapDetail.sourceChainSwapPath[
            sourcePathLength - 1
        ];
        receiveToken(amountIn, tokenInOfSourceChain);

        address recipient = swapDetail.recipient;
        uint256 amountOut;
        if (sourcePathLength > 1) {
            amountOut = ISwapRouter(uniswapRouter).exactInput(
                ISwapRouter.ExactInputParams(
                    abi.encode(swapDetail.sourceChainSwapPath),
                    address(this),
                    maxDeadLine,
                    amountIn,
                    0
                )
            );
        } else {
            amountOut = amountIn;
        }

        if (zetaPathLength == 0) {
            sendPlatformFee(amountOut, tokenOutOfSourceChain, false);
            if (tokenOutOfSourceChain == nativeToken) {
                IWETH(nativeToken).withdraw(amountOut);
                TransferHelper.transferNativeToken(recipient, amountOut);
            } else {
                TransferHelper.safeTransfer(
                    tokenOutOfSourceChain,
                    recipient,
                    amountOut
                );
            }
        } else if (targetPathLength == 0 && zetaPathLength == 1) {
            sendPlatformFee(amountOut, tokenOutOfSourceChain, true);

            tokenOutOfSourceChain == nativeToken
                ? IGatewayEVM(gateWay).deposit(
                    recipient,
                    RevertOptions(
                        address(0),
                        false,
                        address(0),
                        new bytes(0),
                        0
                    )
                )
                : IGatewayEVM(gateWay).deposit(
                    recipient,
                    amountOut,
                    tokenOutOfSourceChain,
                    RevertOptions(
                        address(0),
                        false,
                        address(0),
                        new bytes(0),
                        0
                    )
                );
        } else {
            sendPlatformFee(amountOut, tokenOutOfSourceChain, true);

            tokenOutOfSourceChain == nativeToken
                ? IGatewayEVM(gateWay).depositAndCall(
                    universalContract,
                    abi.encode(swapDetail),
                    RevertOptions(
                        address(0),
                        false,
                        address(0),
                        new bytes(0),
                        0
                    )
                )
                : IGatewayEVM(gateWay).depositAndCall(
                    universalContract,
                    amountOut,
                    tokenOutOfSourceChain,
                    abi.encode(swapDetail),
                    RevertOptions(
                        address(0),
                        false,
                        address(0),
                        new bytes(0),
                        0
                    )
                );
        }
        emit Events.SwapExecuted(
            msg.sender,
            recipient,
            tokenInOfSourceChain,
            tokenOutOfSourceChain,
            amountIn,
            amountOut
        );
    }

    function onReceive(
        address[] memory targetChainSwapPath,
        address recipient,
        uint256 amountIn
    ) external payable whenNotPaused nonReentrant {
        address tokenOutOfTargetChain = targetChainSwapPath[
            targetChainSwapPath.length - 1
        ];
        uint256 amountOut = ISwapRouter(uniswapRouter).exactInput(
            ISwapRouter.ExactInputParams(
                abi.encode(targetChainSwapPath),
                address(this),
                maxDeadLine,
                amountIn,
                0
            )
        );

        if (tokenOutOfTargetChain == nativeToken) {
            IWETH(nativeToken).withdraw(amountOut);
            TransferHelper.transferNativeToken(recipient, amountOut);
        } else {
            TransferHelper.safeTransfer(
                tokenOutOfTargetChain,
                recipient,
                amountOut
            );
        }
    }

    /**
     * @dev Control upgrade authority
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @dev Receive the user's tokens and calculate volume
     */
    function receiveToken(uint256 amountIn, address tokenIn) private {
        if (amountIn == 0) revert Errors.NeedsMoreThanZero();

        if (tokenIn == nativeToken) {
            if (msg.value != amountIn) revert Errors.IncorrectAmountSent();
            IWETH(nativeToken).deposit{value: amountIn}();
            volume += amountIn;
        } else {
            if (IERC20(tokenIn).allowance(msg.sender, address(this)) < amountIn)
                revert Errors.InsufficientAllowance();

            TransferHelper.safeTransferFrom(
                tokenIn,
                msg.sender,
                address(this),
                amountIn
            );
            address[] memory path;
            path[0] = tokenIn;
            path[1] = nativeToken;
            uint256 amountOut = IQuoter(uniswapQuoter).quoteExactInput(
                abi.encode(path),
                amountIn
            );
            volume += amountOut;
        }
        emit Events.ReceivedToken(msg.sender, tokenIn, amountIn);
    }

    /**
     * @dev Send platform fees to the treasury
     */
    function sendPlatformFee(
        uint256 amount,
        address token,
        bool isCrossChain
    ) private returns (uint256 newAmount) {
        if (amount == 0) revert Errors.TransferFailed();
        uint256 feeAmount;
        isCrossChain == true
            ? feeAmount = (amount * crossChainPlatformFee) / 1000
            : feeAmount = (amount * sourceChainPlatformFee) / 1000;
        newAmount = amount - feeAmount;

        if (feeAmount > 0) {
            TransferHelper.safeTransfer(token, kyexTreasury, feeAmount);
        }
        emit Events.ReceivePlatformFee(
            token,
            msg.sender,
            kyexTreasury,
            feeAmount
        );
    }

    ///////////////////
    // receive
    ///////////////////
    receive() external payable {}
}
