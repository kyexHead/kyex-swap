// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "libraries/zetaV2/contracts/zevm/interfaces/IWZETA.sol";
import "libraries/zetaV2/contracts/zevm/interfaces/IZRC20.sol";
import "libraries/zetaV2/contracts/zevm/interfaces/UniversalContract.sol";
import "libraries/zetaV2/contracts/zevm/interfaces/IGatewayZEVM.sol";
import "libraries/TransferHelper.sol";
import "libraries/error/Errors.sol";
import "libraries/event/Events.sol";

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
contract KYEXSwapZeta is
    UniversalContract,
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
        0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;
    address private constant gateWay =
        0x6c533f7fE93fAE114d0954697069Df33C9B74fD7;
    address private constant nativeToken =
        0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;

    address public kyexTreasury;
    uint32 public maxDeadLine;
    uint16 public crossChainPlatformFee;
    uint16 public sourceChainPlatformFee;
    uint256 public volume;

    ///////////////////
    // Modifiers
    ///////////////////
    modifier onlyGateway() {
        if (msg.sender != address(gateWay)) revert Errors.OnlyGateWay();
        _;
    }

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
     * @dev Withdraw ZETA from the contract, only the owner can execute this operation
     */
    function withdrawZETA() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert Errors.InsufficientFunds();
        TransferHelper.transferNativeToken(owner(), balance);

        emit Events.WithdrawnNativeToken(owner(), balance);
    }

    /**
     * @dev Withdraw ZRC20 from the contract, only the owner can execute this operation
     */
    function withdrawZRC20(address zrc20Address) external onlyOwner {
        uint256 balance = IZRC20(zrc20Address).balanceOf(address(this));
        if (balance == 0) revert Errors.InsufficientFunds();
        TransferHelper.safeTransfer(zrc20Address, owner(), balance);

        emit Events.Withdrawn(owner(), zrc20Address, balance);
    }

    function swap(
        uint256 amountIn,
        SwapDetail calldata swapDetail
    ) external payable whenNotPaused nonReentrant {
        uint256 zetaPathLength = swapDetail.zetaChainSwapPath.length;
        uint256 targetPathLength = swapDetail.targetChainSwapPath.length;
        address tokenInOfZetaChain = swapDetail.zetaChainSwapPath[0];
        address tokenOutOfZetaChain = swapDetail.zetaChainSwapPath[
            zetaPathLength - 1
        ];
        receiveToken(amountIn, tokenInOfZetaChain);

        uint256 amountOut;
        address recipient = swapDetail.recipient;
        if (zetaPathLength > 1) {
            uint256[] memory amount = IUniswapV2Router02(uniswapRouter)
                .swapExactTokensForTokens(
                    amountIn,
                    0,
                    swapDetail.zetaChainSwapPath,
                    address(this),
                    maxDeadLine
                );
            amountOut = amount[1];
        } else {
            amountOut = amountIn;
        }

        if (targetPathLength == 0) {
            sendPlatformFee(amountOut, tokenOutOfZetaChain, false);
            if (tokenOutOfZetaChain == nativeToken) {
                IWETH9(nativeToken).withdraw(amountOut);
                TransferHelper.transferNativeToken(recipient, amountOut);
            } else {
                TransferHelper.safeTransfer(
                    tokenOutOfZetaChain,
                    recipient,
                    amountOut
                );
            }
        } else if (targetPathLength == 1 && zetaPathLength == 1) {
            sendPlatformFee(amountOut, tokenOutOfZetaChain, true);
            IGatewayZEVM(gateWay).withdraw(
                abi.encode(recipient),
                amountOut,
                tokenOutOfZetaChain,
                RevertOptions(address(0), false, address(0), new bytes(0), 0)
            );
        } else {
            sendPlatformFee(amountOut, tokenOutOfZetaChain, true);
            IGatewayZEVM(gateWay).withdrawAndCall(
                swapDetail.omnichainSwapContract,
                amountOut,
                swapDetail.chainId,
                abi.encodeWithSignature(
                    "onReceive(address[],address,uint256)",
                    swapDetail.targetChainSwapPath,
                    recipient,
                    amountOut
                ),
                CallOptions(30000, false),
                RevertOptions(address(0), false, address(0), new bytes(0), 0)
            );
        }
        emit Events.SwapExecuted(
            msg.sender,
            recipient,
            tokenInOfZetaChain,
            tokenOutOfZetaChain,
            amountIn,
            amountOut
        );
    }

    function onCall(
        MessageContext calldata /*context*/,
        address tokenInOfZetaChain,
        uint256 amountIn,
        bytes calldata message
    ) external override onlyGateway whenNotPaused {
        SwapDetail memory swapDetail = abi.decode(message, (SwapDetail));

        uint256 amountOut;
        uint256 zetaPathLength = swapDetail.zetaChainSwapPath.length;
        uint256 targetPathLength = swapDetail.targetChainSwapPath.length;
        uint256 gasZRC20PathLength = swapDetail.gasZRC20SwapPath.length;
        address tokenOutOfZetaChain = swapDetail.zetaChainSwapPath[
            zetaPathLength - 1
        ];
        address recipient = swapDetail.recipient;
        uint256 gasFee = swapDetail.gasFee;

        if (zetaPathLength == 3 && gasZRC20PathLength == 3) {
            address[] memory path;
            path[0] = tokenInOfZetaChain;
            path[1] = nativeToken;
            // tokenIn -- zeta
            uint256[] memory amountOfZeta = IUniswapV2Router02(uniswapRouter)
                .swapExactTokensForTokens(
                    amountIn,
                    0,
                    path,
                    address(this),
                    block.timestamp + maxDeadLine
                );
            // zeta -- gasZRC20
            path[0] = nativeToken;
            path[1] = swapDetail.gasZRC20SwapPath[2];
            uint256[] memory amountOfGasZRC20 = IUniswapV2Router02(
                uniswapRouter
            ).swapTokensForExactTokens(
                    gasFee,
                    amountOfZeta[1],
                    path,
                    address(this),
                    block.timestamp + maxDeadLine
                );
            // zeta -- tokenOut
            path[1] = tokenOutOfZetaChain;
            uint256[] memory amount = IUniswapV2Router02(uniswapRouter)
                .swapExactTokensForTokens(
                    amountOfZeta[1] - amountOfGasZRC20[0],
                    0,
                    path,
                    address(this),
                    block.timestamp + maxDeadLine
                );
            amountOut = amount[1];
        } else if (gasZRC20PathLength > 1) {
            uint256[] memory amount = IUniswapV2Router02(uniswapRouter)
                .swapExactTokensForTokens(
                    amountIn,
                    0,
                    swapDetail.zetaChainSwapPath,
                    address(this),
                    block.timestamp + maxDeadLine
                );

            uint256[] memory amountOfGasZRC20 = IUniswapV2Router02(
                uniswapRouter
            ).swapTokensForExactTokens(
                    gasFee,
                    amount[1],
                    swapDetail.gasZRC20SwapPath,
                    address(this),
                    block.timestamp + maxDeadLine
                );
            amountOut = amount[1] - amountOfGasZRC20[0];
        } else if (gasZRC20PathLength == 1) {
            uint256[] memory amount = IUniswapV2Router02(uniswapRouter)
                .swapExactTokensForTokens(
                    amountIn,
                    0,
                    swapDetail.zetaChainSwapPath,
                    address(this),
                    block.timestamp + maxDeadLine
                );
            amountOut = amount[1] - gasFee;
        } else {
            uint256[] memory amount = IUniswapV2Router02(uniswapRouter)
                .swapExactTokensForTokens(
                    amountIn,
                    0,
                    swapDetail.zetaChainSwapPath,
                    address(this),
                    block.timestamp + maxDeadLine
                );
            amountOut = amount[1];
        }

        if (targetPathLength > 1) {
            IGatewayZEVM(gateWay).withdrawAndCall(
                abi.encode(swapDetail.omnichainSwapContract),
                amountOut,
                tokenOutOfZetaChain,
                abi.encodeWithSignature(
                    "onReceive(address[],address,uint256)",
                    swapDetail.targetChainSwapPath,
                    recipient,
                    amountOut
                ),
                CallOptions(30000, false),
                RevertOptions(address(0), false, address(0), new bytes(0), 0)
            );
        } else if (targetPathLength == 1) {
            IGatewayZEVM(gateWay).withdraw(
                abi.encode(recipient),
                amountOut,
                tokenOutOfZetaChain,
                RevertOptions(address(0), false, address(0), new bytes(0), 0)
            );
        } else {
            TransferHelper.safeTransfer(
                tokenOutOfZetaChain,
                recipient,
                amountOut
            );
        }
        emit Events.onCallExecuted(
            tokenInOfZetaChain,
            tokenOutOfZetaChain,
            amountIn,
            amountOut,
            recipient
        );
    }

    ///////////////////
    // Internal Function
    ///////////////////
    /**
     * @dev Control upgrade authority
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

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

    /**
     * @dev Receive the user's tokens and calculate volume
     */
    function receiveToken(uint256 amountIn, address tokenIn) private {
        if (amountIn == 0) revert Errors.NeedsMoreThanZero();

        if (tokenIn == nativeToken) {
            if (msg.value != amountIn) revert Errors.IncorrectAmountSent();
            IWETH9(nativeToken).deposit{value: amountIn}();
            volume += amountIn;
        } else {
            if (IZRC20(tokenIn).allowance(msg.sender, address(this)) < amountIn)
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
            uint256[] memory amount = IUniswapV2Router02(uniswapRouter)
                .getAmountsOut(amountIn, path);

            volume += amount[1];
        }
        emit Events.ReceivedToken(msg.sender, tokenIn, amountIn);
    }

    ///////////////////
    // receive
    ///////////////////
    receive() external payable {}
}
