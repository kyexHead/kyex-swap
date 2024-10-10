// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "libraries/zetaV2/interfaces/IZRC20.sol";
import "libraries/zetaV2/interfaces/IWZETA.sol";
import "libraries/TransferHelper.sol";
import "libraries/error/Errors.sol";
import "libraries/zetaV2/interfaces/ZetaInterfaces.sol";
import "hardhat/console.sol";

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
 * @dev KYEX Mainnet ZETACHAIN zrcSwap Smart Contract V1
 */
contract KYEXSwap01 is
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    ///////////////////
    // State Variables
    ///////////////////
    address private WZETA; // Note:when deploying on the mainnet，This should be changed to 【 address public constant WZETA = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf; 】
    address private constant BITCOIN =
        0x13A0c5930C028511Dc02665E7285134B6d11A5f4; // Note:when deploying on the testnet，This should be changed to 【 address public constant BITCOIN = 0x65a45c57636f9BcCeD4fe193A602008578BcA90b; 】
    address private UniswapRouter;
    address private UniswapFactory;
    address private kyexTreasury;
    ZetaConnector private connector;
    uint32 private MAX_DEADLINE;

    uint16 public platformFee;
    uint256 public volume;

    ///////////////////
    // Events
    ///////////////////
    event SwapExecuted(
        address indexed sender,
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    );
    event PerformSwap(
        address tokenA,
        address tokenB,
        uint256 amountIn,
        uint256 amountOut
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
        uint8 chainId
    );
    event ZETAWithdrawn(address indexed owner, uint256 amount);
    event ZRC20Withdrawn(address indexed owner, uint256 amount);
    event ReceivePlatformFee(
        address indexed token,
        address indexed sender,
        address receiver,
        uint256 amount
    );

    ///////////////////
    // Initialize Function
    ///////////////////

    /**
     * @notice To Iinitialize contract after deployed.
     */
    function initialize(
        address _WZETA, //Note: when deploying on the mainnet，this line should be deleted.
        address _UniswapRouter,
        address _UniswapFactory,
        address _kyexTreasury,
        uint32 _MAX_DEADLINE,
        uint16 _platformFee,
        address _connectorAddress
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        WZETA = _WZETA; //Note: when deploying on the mainnet，this line should be deleted.
        UniswapRouter = _UniswapRouter;
        UniswapFactory = _UniswapFactory;
        kyexTreasury = _kyexTreasury;
        MAX_DEADLINE = _MAX_DEADLINE;
        platformFee = _platformFee;
        volume = 0;
        connector = ZetaConnector(_connectorAddress);
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
        uint16 _newFee,
        address _newAddress,
        uint32 max_deadline
    ) external onlyOwner {
        platformFee = _newFee;
        kyexTreasury = _newAddress;
        MAX_DEADLINE = max_deadline;
    }

    /**
     * @dev update uniswap
     */
    function updateUniswap(
        address _UniswapFactory,
        address _UniswapRouter
    ) external onlyOwner {
        UniswapFactory = _UniswapFactory;
        UniswapRouter = _UniswapRouter;
    }

    /**
     * @dev update zetaConnector
     */
    function updateZetaConnector(address _connectorAddress) external onlyOwner {
        connector = ZetaConnector(_connectorAddress);
    }

    /**
     * @dev Withdraw ZETA from the contract, only the owner can execute this operation
     */
    function withdrawZETA() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert Errors.InsufficientFunds();

        TransferHelper.safeTransferZETA(owner(), balance);

        emit ZETAWithdrawn(owner(), balance);
    }

    /**
     * @dev Withdraw ZRC20 from the contract, only the owner can execute this operation
     */
    function withdrawZRC20(address zrc20Address) external onlyOwner {
        uint256 balance = IZRC20(zrc20Address).balanceOf(address(this));
        if (balance == 0) revert Errors.InsufficientFunds();

        TransferHelper.safeTransfer(zrc20Address, owner(), balance);

        emit ZRC20Withdrawn(owner(), balance);
    }

    function swapFromZetaChainToAny(
        address tokenInOfZetaChain,
        address tokenOutOfZetaChain,
        uint256 amountIn,
        bytes memory btcRecipient,
        uint256 minAmountOut,
        bool isCrossChain,
        uint8 chainId
    ) external payable whenNotPaused nonReentrant {
        receiveToken(amountIn, tokenInOfZetaChain);

        uint256 amountOut;
        if (!isCrossChain) {
            amountOut = swapTokens(
                tokenInOfZetaChain,
                tokenOutOfZetaChain,
                amountIn,
                0,
                minAmountOut,
                true
            );
            amountOut = sendPlatformFee(amountOut, tokenOutOfZetaChain);

            sendToUser(
                isCrossChain,
                tokenOutOfZetaChain,
                btcRecipient,
                address(0),
                0,
                amountOut,
                chainId
            );
        } else {
            (address gasZRC20, uint256 gasFee) = IZRC20(tokenOutOfZetaChain)
                .withdrawGasFee();
            if (tokenInOfZetaChain == gasZRC20) {
                amountOut = swapTokens(
                    tokenInOfZetaChain,
                    tokenOutOfZetaChain,
                    amountIn - gasFee,
                    0,
                    minAmountOut,
                    true
                );
            } else if (tokenOutOfZetaChain == gasZRC20) {
                amountOut = swapTokens(
                    tokenInOfZetaChain,
                    tokenOutOfZetaChain,
                    amountIn,
                    0,
                    minAmountOut,
                    true
                );
                amountOut -= gasFee;
            } else {
                amountOut = swapTokens(
                    tokenInOfZetaChain,
                    tokenOutOfZetaChain,
                    amountIn,
                    0,
                    minAmountOut,
                    true
                );
                uint256 gasFeeWithTokenOut = swapTokens(
                    tokenOutOfZetaChain,
                    gasZRC20,
                    amountOut,
                    gasFee,
                    0,
                    false
                );
                amountOut -= gasFeeWithTokenOut;
            }

            amountOut = sendPlatformFee(amountOut, tokenOutOfZetaChain);
            sendToUser(
                isCrossChain,
                tokenOutOfZetaChain,
                btcRecipient,
                gasZRC20,
                gasFee,
                amountOut,
                chainId
            );
        }
        (tokenInOfZetaChain == WZETA)
            ? volume += amountIn
            : volume += getZetaQuote(tokenInOfZetaChain, WZETA, amountIn);
        emit SwapExecuted(
            msg.sender,
            tokenInOfZetaChain,
            tokenOutOfZetaChain,
            amountIn,
            amountOut
        );
    }

    ///////////////////
    // Internal Function
    ///////////////////
    /**
     * @dev Control upgrade authority
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    ///////////////////
    // Private Function
    ///////////////////
    /**
     * @dev Calculate trading volume and standardize tokenIn to WZETA
     */
    function getZetaQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) private view returns (uint256 amount) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        uint256[] memory amounts = IUniswapV2Router02(UniswapRouter)
            .getAmountsOut(amountIn, path);
        return amounts[1];
    }

    function receiveToken(uint256 amountIn, address tokenIn) private {
        if (amountIn == 0) revert Errors.NeedsMoreThanZero();

        if (tokenIn == WZETA) {
            if (msg.value != amountIn)
                revert Errors.IncorrectAmountOfZETASent();

            IWETH9(WZETA).deposit{value: amountIn}();
        } else {
            if (IZRC20(tokenIn).allowance(msg.sender, address(this)) < amountIn)
                revert Errors.InsufficientAllowance();

            TransferHelper.safeTransferFrom(
                tokenIn,
                msg.sender,
                address(this),
                amountIn
            );
        }
        TransferHelper.safeApprove(tokenIn, UniswapRouter, amountIn);

        emit ReceivedToken(msg.sender, tokenIn, amountIn);
    }

    function sendPlatformFee(
        uint256 amount,
        address token
    ) private returns (uint256 newAmount) {
        if (amount == 0) revert Errors.TransferFailed();
        uint256 feeAmount = (amount * platformFee) / 1000;
        newAmount = amount - feeAmount;

        if (feeAmount > 0) {
            TransferHelper.safeTransfer(token, kyexTreasury, feeAmount);
        }
        console.log("feeAmount", feeAmount);
        emit ReceivePlatformFee(token, msg.sender, kyexTreasury, feeAmount);
    }

    function swapTokens(
        address tokenA,
        address tokenB,
        uint256 amountIn,
        uint256 gasFee,
        uint256 minAmountOut,
        bool isExactInputToken
    ) private returns (uint256 amount) {
        address[] memory path;

        address pairAddress = IUniswapV2Factory(UniswapFactory).getPair(
            tokenA,
            tokenB
        );
        if (pairAddress != address(0)) {
            path = new address[](2);
            path[0] = tokenA;
            path[1] = tokenB;
            amount = swapOnUniswap(
                isExactInputToken,
                amountIn,
                gasFee,
                path,
                minAmountOut
            );
        } else {
            path = new address[](3);
            path[0] = tokenA;
            path[1] = WZETA;
            path[2] = tokenB;
            amount = swapOnUniswap(
                isExactInputToken,
                amountIn,
                gasFee,
                path,
                minAmountOut
            );
        }
        emit PerformSwap(tokenA, tokenB, amountIn, amount);
    }

    function swapOnUniswap(
        bool isExactInputToken,
        uint256 amountIn,
        uint256 gasFee,
        address[] memory path,
        uint256 minAmountOut
    ) private returns (uint256 amount) {
        uint256[] memory amounts;

        if (isExactInputToken) {
            amounts = IUniswapV2Router02(UniswapRouter)
                .swapExactTokensForTokens(
                    amountIn,
                    minAmountOut,
                    path,
                    address(this),
                    block.timestamp + MAX_DEADLINE
                );
            amount = amounts[1];
        } else {
            amounts = IUniswapV2Router02(UniswapRouter)
                .swapTokensForExactTokens(
                    gasFee,
                    0,
                    path,
                    address(this),
                    block.timestamp + MAX_DEADLINE
                );
            amount = amounts[0];
        }
        if (amount == 0) revert Errors.SwapFailed();
    }

    function sendToUser(
        bool isCrossChain,
        address token,
        bytes memory btcRecipient,
        address gasZRC20,
        uint256 gasFee,
        uint256 amount,
        uint8 chainId
    ) private {
        if (token == WZETA) {
            sendZeta(isCrossChain, chainId, amount);
        }
        if (isCrossChain) {
            if (token != gasZRC20) {
                TransferHelper.safeApprove(gasZRC20, token, gasFee);
            }
            if (token == BITCOIN) {
                IZRC20(token).withdraw(btcRecipient, amount);
            } else {
                IZRC20(token).withdraw(abi.encodePacked(msg.sender), amount);
            }
        } else {
            TransferHelper.safeTransfer(token, msg.sender, amount);
        }
        emit TokenTransfer(
            isCrossChain,
            token,
            msg.sender,
            gasZRC20,
            gasFee,
            amount,
            chainId
        );
    }

    function sendZeta(
        bool isCrossChain,
        uint8 chainId,
        uint256 amount
    ) private {
        if (isCrossChain) {
            transferZETAout(chainId, abi.encodePacked(msg.sender), amount);
        } else {
            IWETH9(WZETA).withdraw(amount);
            TransferHelper.safeTransferZETA(msg.sender, amount);
        }
    }

    /**
     * @dev Transfer WZETA to other native chain.
     */
    function transferZETAout(
        uint256 destinationChainId,
        bytes memory destinationAddress,
        uint256 destinationAmount
    ) private {
        TransferHelper.safeApprove(
            WZETA,
            address(connector),
            destinationAmount
        );
        connector.send(
            ZetaInterfaces.SendInput({
                destinationChainId: destinationChainId,
                destinationAddress: destinationAddress,
                destinationGasLimit: 300000,
                message: abi.encode(),
                zetaValueAndGas: destinationAmount,
                zetaParams: abi.encode("")
            })
        );
    }

    ///////////////////
    // receive
    ///////////////////
    receive() external payable {}
}
