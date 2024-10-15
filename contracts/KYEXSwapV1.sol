// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "libraries/zetaV2/interfaces/IWZETA.sol";
import "libraries/zetaV2/SystemContract.sol";
import "libraries/TransferHelper.sol";
import "libraries/error/Errors.sol";
import "libraries/zetaV2/interfaces/zContract.sol";
import "libraries/zetaV2/interfaces/ZetaInterfaces.sol";

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
contract KYEXSwapV1 is
    zContract,
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    ///////////////////
    // Struct
    ///////////////////
    struct ZetaSystemConfig {
        address UniswapFactory;
        address UniswapRouter;
        address WZETA;
        address connector;
    }

    struct SwapResult {
        uint256 amountOut;
        address gasZRC20;
        uint256 gasFee;
    }

    ///////////////////
    // State Variables
    ///////////////////
    address private BITCOIN;
    SystemContract private ZetaSystemContract;
    address private kyexTreasury;
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
        uint256 chainId
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
    // Modifiers
    ///////////////////
    modifier onlySystem(SystemContract _systemContract) {
        if (msg.sender != address(_systemContract))
            revert Errors.OnlySystemContract();
        _;
    }

    ///////////////////
    // Initialize Function
    ///////////////////

    /**
     * @notice To Iinitialize contract after deployed.
     */
    function initialize(
        address _kyexTreasury,
        uint32 _MAX_DEADLINE,
        uint16 _platformFee,
        address _systemContract,
        address _bitCoin
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        kyexTreasury = _kyexTreasury;
        MAX_DEADLINE = _MAX_DEADLINE;
        platformFee = _platformFee;
        ZetaSystemContract = SystemContract(_systemContract);
        BITCOIN = _bitCoin;
        volume = 0;
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
     * @dev update systemContract
     */
    function updateZetaSystemContract(
        address _systemContract
    ) external onlyOwner {
        ZetaSystemContract = SystemContract(_systemContract);
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
        uint256 chainId
    ) external payable whenNotPaused nonReentrant {
        ZetaSystemConfig memory zetaSystemConfig = getConfigFromSystem();

        receiveToken(amountIn, tokenInOfZetaChain, zetaSystemConfig.WZETA);
        TransferHelper.safeApprove(
            tokenInOfZetaChain,
            zetaSystemConfig.UniswapRouter,
            amountIn
        );

        SwapResult memory swapResult = calculateAmountOut(
            isCrossChain,
            zetaSystemConfig,
            tokenInOfZetaChain,
            tokenOutOfZetaChain,
            amountIn,
            minAmountOut
        );

        sendToUser(
            zetaSystemConfig.WZETA,
            isCrossChain,
            tokenOutOfZetaChain,
            btcRecipient,
            msg.sender,
            swapResult,
            chainId,
            zetaSystemConfig.connector
        );
        calculateVolume(
            tokenInOfZetaChain,
            amountIn,
            zetaSystemConfig.UniswapRouter,
            zetaSystemConfig.WZETA
        );
        emit SwapExecuted(
            msg.sender,
            tokenInOfZetaChain,
            tokenOutOfZetaChain,
            amountIn,
            swapResult.amountOut
        );
    }

    function onCrossChainCall(
        zContext calldata /* context */,
        address tokenInOfZetaChain,
        uint256 amountIn,
        bytes calldata message
    ) external override onlySystem(ZetaSystemContract) whenNotPaused {
        (
            bool isCrossChain,
            uint256 minAmountOut,
            address tokenOutOfZetaChain,
            bytes memory recipient
        ) = abi.decode(message, (bool, uint256, address, bytes));

        ZetaSystemConfig memory zetaSystemConfig = getConfigFromSystem();

        SwapResult memory swapResult = calculateAmountOut(
            isCrossChain,
            zetaSystemConfig,
            tokenInOfZetaChain,
            tokenOutOfZetaChain,
            amountIn,
            minAmountOut
        );

        address addrOfRecipient = address(uint160(bytes20(recipient)));
        sendToUser(
            zetaSystemConfig.WZETA,
            isCrossChain,
            tokenOutOfZetaChain,
            recipient,
            addrOfRecipient,
            swapResult,
            0,
            zetaSystemConfig.connector
        );
        calculateVolume(
            tokenInOfZetaChain,
            amountIn,
            zetaSystemConfig.UniswapRouter,
            zetaSystemConfig.WZETA
        );
        emit SwapExecuted(
            addrOfRecipient,
            tokenInOfZetaChain,
            tokenOutOfZetaChain,
            amountIn,
            swapResult.amountOut
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
    function calculateVolume(
        address tokenIn,
        uint256 amountIn,
        address UniswapRouter,
        address WZETA
    ) private {
        if (tokenIn == WZETA) {
            volume += amountIn;
        } else {
            address[] memory path = new address[](2);
            path[0] = tokenIn;
            path[1] = WZETA;
            uint256[] memory amounts = IUniswapV2Router02(UniswapRouter)
                .getAmountsOut(amountIn, path);
            volume += amounts[1];
        }
    }

    function receiveToken(
        uint256 amountIn,
        address tokenIn,
        address WZETA
    ) private {
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
        emit ReceivedToken(msg.sender, tokenIn, amountIn);
    }

    function calculateAmountOut(
        bool isCrossChain,
        ZetaSystemConfig memory zetaSystemConfig,
        address tokenInOfZetaChain,
        address tokenOutOfZetaChain,
        uint256 amountIn,
        uint256 minAmountOut
    ) private returns (SwapResult memory) {
        uint256 amountOut;
        address gasZRC20;
        uint256 gasFee;
        if (!isCrossChain) {
            amountOut = swapTokens(
                zetaSystemConfig.UniswapFactory,
                zetaSystemConfig.UniswapRouter,
                zetaSystemConfig.WZETA,
                tokenInOfZetaChain,
                tokenOutOfZetaChain,
                amountIn,
                0,
                minAmountOut,
                true
            );
        } else {
            (gasZRC20, gasFee) = IZRC20(tokenOutOfZetaChain).withdrawGasFee();
            if (gasFee == 0) revert Errors.InvalidZetaValueAndGas();
            if (tokenInOfZetaChain == gasZRC20) {
                amountOut = swapTokens(
                    zetaSystemConfig.UniswapFactory,
                    zetaSystemConfig.UniswapRouter,
                    zetaSystemConfig.WZETA,
                    tokenInOfZetaChain,
                    tokenOutOfZetaChain,
                    amountIn - gasFee,
                    0,
                    minAmountOut,
                    true
                );
            } else if (tokenOutOfZetaChain == gasZRC20) {
                amountOut = swapTokens(
                    zetaSystemConfig.UniswapFactory,
                    zetaSystemConfig.UniswapRouter,
                    zetaSystemConfig.WZETA,
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
                    zetaSystemConfig.UniswapFactory,
                    zetaSystemConfig.UniswapRouter,
                    zetaSystemConfig.WZETA,
                    tokenInOfZetaChain,
                    tokenOutOfZetaChain,
                    amountIn,
                    0,
                    minAmountOut,
                    true
                );
                TransferHelper.safeApprove(
                    tokenOutOfZetaChain,
                    zetaSystemConfig.UniswapRouter,
                    amountOut
                );
                uint256 gasFeeWithTokenOut = swapTokens(
                    zetaSystemConfig.UniswapFactory,
                    zetaSystemConfig.UniswapRouter,
                    zetaSystemConfig.WZETA,
                    tokenOutOfZetaChain,
                    gasZRC20,
                    amountOut,
                    gasFee,
                    0,
                    false
                );
                amountOut -= gasFeeWithTokenOut;
            }
        }
        amountOut = sendPlatformFee(amountOut, tokenOutOfZetaChain);
        return
            SwapResult({
                amountOut: amountOut,
                gasZRC20: gasZRC20,
                gasFee: gasFee
            });
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
        emit ReceivePlatformFee(token, msg.sender, kyexTreasury, feeAmount);
    }

    function swapTokens(
        address UniswapFactory,
        address UniswapRouter,
        address WZETA,
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
                UniswapRouter,
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
                UniswapRouter,
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
        address UniswapRouter,
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
            amount = amounts[path.length - 1];
        } else {
            amounts = IUniswapV2Router02(UniswapRouter)
                .swapTokensForExactTokens(
                    gasFee,
                    amountIn,
                    path,
                    address(this),
                    block.timestamp + MAX_DEADLINE
                );
            amount = amounts[0];
        }
        if (amount == 0) revert Errors.SwapFailed();
    }

    function sendToUser(
        address WZETA,
        bool isCrossChain,
        address token,
        bytes memory bytesOfReceipient,
        address addrOfreceipient,
        SwapResult memory swapResult,
        uint256 chainId,
        address connector
    ) private {
        if (isCrossChain) {
            TransferHelper.safeApprove(
                swapResult.gasZRC20,
                token,
                swapResult.gasFee
            );
            if (token == BITCOIN) {
                IZRC20(token).withdraw(bytesOfReceipient, swapResult.amountOut);
            } else if (token == WZETA) {
                transferZETAout(
                    WZETA,
                    connector,
                    chainId,
                    bytesOfReceipient,
                    swapResult.amountOut
                );
            } else {
                IZRC20(token).withdraw(bytesOfReceipient, swapResult.amountOut);
            }
        } else {
            if (token == WZETA) {
                IWETH9(WZETA).withdraw(swapResult.amountOut);
                TransferHelper.safeTransferZETA(
                    addrOfreceipient,
                    swapResult.amountOut
                );
            } else {
                TransferHelper.safeTransfer(
                    token,
                    addrOfreceipient,
                    swapResult.amountOut
                );
            }
        }
        emit TokenTransfer(
            isCrossChain,
            token,
            addrOfreceipient,
            swapResult.gasZRC20,
            swapResult.gasFee,
            swapResult.amountOut,
            chainId
        );
    }

    /**
     * @dev Transfer WZETA to other native chain.
     */
    function transferZETAout(
        address WZETA,
        address connector,
        uint256 destinationChainId,
        bytes memory destinationAddress,
        uint256 destinationAmount
    ) private {
        TransferHelper.safeApprove(WZETA, connector, destinationAmount);
        ZetaConnector(connector).send(
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

    function getConfigFromSystem()
        private
        view
        returns (ZetaSystemConfig memory)
    {
        return
            ZetaSystemConfig({
                UniswapFactory: ZetaSystemContract.uniswapv2FactoryAddress(),
                UniswapRouter: ZetaSystemContract.uniswapv2Router02Address(),
                WZETA: ZetaSystemContract.wZetaContractAddress(),
                connector: ZetaSystemContract.zetaConnectorZEVMAddress()
            });
    }

    ///////////////////
    // receive
    ///////////////////
    receive() external payable {}
}
