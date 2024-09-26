// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "libraries/UniswapV2Library.sol";
import "libraries/SwapHelperLib.sol";
import "libraries/TransferHelper.sol";
import "libraries/BytesHelperLib.sol";
import "libraries/zetaV2/interfaces/IWZETA.sol";
import "libraries/error/Errors.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

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
 * @title KYEX Cross-Chain Swap
 * @author KYEX-TEAM
 * @notice KYEX Mainnet Main kyexSwap Smart Contract V1
 */
contract KYEXSwap02 is zContract, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable {
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
    address private kyexTreasury;
    uint32 private MAX_DEADLINE;
    uint16 private platformFee;
    uint16 private MAX_SLIPPAGE;
    SystemContract private systemContract;
    uint256 public volume;

    ///////////////////
    // Events
    ///////////////////
    event PlatformFeeSent(uint256 amount, address zrc20);
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
    event ZETAWithdrawn(address indexed owner, uint256 zetaAmount, uint256 wzetaAmount);
    event TokenWithdrawn(address indexed token, address indexed treasury, uint256 amount);

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

    /**
     * @notice To Iinitialize contract after deployed.
     */
    function initialize(
        address _WZETA, //Note: when deploying on the mainnet，this line should be deleted.
        address _kyexTreasury,
        uint32 _MAX_DEADLINE,
        uint16 _platformFee,
        uint16 _MAX_SLIPPAGE,
        address _systemContract
    ) external initializer {
        __Ownable_init();
        __Pausable_init();

        WZETA = _WZETA; //Note: when deploying on the mainnet，this line should be deleted.
        kyexTreasury = _kyexTreasury;
        MAX_DEADLINE = _MAX_DEADLINE;
        platformFee = _platformFee;
        MAX_SLIPPAGE = _MAX_SLIPPAGE;
        systemContract = SystemContract(_systemContract);
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
     * @dev Withdraw ZETA from the contract, only the owner can execute this operation
     */
    function withdrawZETA() external onlyOwner {
        uint256 zetaBalance = address(this).balance;
        uint256 wzetaBalance = IWETH9(WZETA).balanceOf(address(this));

        // Check for insufficient funds after the transfer
        if (zetaBalance == 0 && wzetaBalance == 0) revert Errors.InsufficientFunds(); 
        
        // 1. Transfer tZETA
        if (zetaBalance > 0) {
            (bool zetaTransferSuccess, ) = kyexTreasury.call{value: zetaBalance}("");
            if (!zetaTransferSuccess) revert Errors.TransferFailed();
        }

        // 2. Transfer wZETA (if applicable)
        if (wzetaBalance > 0) {
            IWETH9(WZETA).transfer(kyexTreasury, wzetaBalance);
        }

        emit ZETAWithdrawn(kyexTreasury, zetaBalance, wzetaBalance);
    }

    /**
     * @dev Withdraw ZRC token from the contract, only the owner can execute this operation
     */
    function withdrawZRCTokens(address tokenAddress) external onlyOwner {
        uint256 zrc20Balance = IZRC20(tokenAddress).balanceOf(address(this));
        if (zrc20Balance == 0) revert Errors.InsufficientFunds();
        if (zrc20Balance > 0) {
            IZRC20(tokenAddress).transfer(kyexTreasury, zrc20Balance);
        }
        emit TokenWithdrawn(tokenAddress, kyexTreasury, zrc20Balance);
    }

    /**
     * @dev Enables cross-chain token swaps, likely utilizing ZetaChain for bridging.
     *
     * @param context: ZetaChain context data.
     * @param zrc20: Address of the ZRC20 token being swapped.
     * @param amount: Amount of the ZRC20 token.
     * @param message: Encoded message containing swap details (isWithdraw, slippage, targetTokenAddress, sameNetworkAddress, recipientAddress)
     * @notice Handles scenarios based on isWithdraw value:
     *          0: Same-network swap
     *          1: Wrap and transfer (for WZETA)
     *          2: Unwrap and transfer (for WZETA)
     *          3: Transfer ERC20 token
     *          4: Deposit ZRC20 token
     */
    function onCrossChainCall(zContext calldata context, address zrc20, uint256 amount, bytes calldata message)
        external
        override
        onlySystem(systemContract)
        whenNotPaused
    {
        (
            uint32 isWithdraw,
            uint32 slippage,
            address targetTokenAddress,
            bytes memory recipientAddress
        ) = decodeMessage(message, context.chainID);

        // FOR SOLANA DEPOSIT METHOD
        if (isWithdraw == 4) {
            //Deposit ZRC20 token
            depositZRC(zrc20, amount, address(uint160(bytes20(recipientAddress))));
        } else {
            (SwapAmounts memory swapAmounts) = calculateSwapAmounts(zrc20, targetTokenAddress, amount, slippage);

            uint256 feeAmount = swapAmounts.outputAmount * platformFee / 10000;
            uint256 newAmount = swapAmounts.outputAmount - feeAmount;

            if (feeAmount > 0) {
                TransferHelper.safeTransfer(targetTokenAddress, kyexTreasury, feeAmount);
            }

            address recipient = address(uint160(bytes20(recipientAddress)));
            //targetToken is ZETA
            if (swapAmounts.isTargetZeta) {
                if (isWithdraw == 1) {
                    //Wrap and transfer (for WZETA)
                    wrapAndTransfer(swapAmounts.wzeta, newAmount, recipient);
                } else if (isWithdraw == 2) {
                    //Unwrap and transfer (for WZETA)
                    unWrapAndTransfer(swapAmounts.wzeta, newAmount, recipient);
                }
                //targetToken is ZRC20
            } else {
                if (isWithdraw == 1) {
                    transferZRC20(targetTokenAddress, newAmount, recipient);
                } else if (isWithdraw == 2) {
                    withdrawZRC(
                        swapAmounts.gasZRC20, swapAmounts.gasFee, targetTokenAddress, newAmount, recipientAddress
                    );
                }
            }
            (zrc20 == WZETA) ? volume += amount : volume += getZetaQuote(zrc20, WZETA, amount);

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

    function getPlatformFee() public view returns (uint256) {
        return platformFee;
    }

    function updateTreasuryAddress(address _newAddress) external onlyOwner {
        kyexTreasury = _newAddress;
    }

    function updatePlatformFee(uint16 _newFee) external onlyOwner {
        platformFee = _newFee;
    }

    function updateSlippage(uint16 _slippage) external onlyOwner {
        MAX_SLIPPAGE = _slippage;
    }

    function updateMaxDeadLine(uint32 _maxDeadLine) external onlyOwner {
        MAX_DEADLINE = _maxDeadLine;
    }

    function updateSystemContract(address _systemContract) external onlyOwner {
        systemContract = SystemContract(_systemContract);
    }

    ///////////////////
    // Internal Function
    ///////////////////
    /**
     * @dev Control upgrade authority
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @dev Calculate trading volume and standardize tokenIn to WZETA
     */
    function getZetaQuote(address tokenIn, address tokenOut, uint256 amountIn) internal view returns (uint256 amount) {
        (uint256 reserveA, uint256 reserveB) =
            UniswapV2Library.getReserves(systemContract.uniswapv2FactoryAddress(), tokenIn, tokenOut);
        amount = UniswapV2Library.quote(amountIn, reserveA, reserveB);
    }

    function depositZRC(address tokenAddress, uint256 amount, address recipientAddress) internal {
        address recipient = address(uint160(bytes20(recipientAddress)));
        bool transferSuccess = IZRC20(tokenAddress).transfer(recipient, amount);

        require(transferSuccess, "Transfer Fail");
        if (!transferSuccess) revert Errors.TransferFailed();
        emit WrappedTokenTransfer(amount, recipient);
    }

    function wrapAndTransfer(address wzeta, uint256 amount, address recipient) internal {
        // Transfer Wrap ZETA
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
        uint256 outputAmount = SwapHelperLib.swapExactTokensForTokens(
            systemContract, zrc20, amount, targetTokenAddress, 0, slippage, MAX_DEADLINE
        );
        if (outputAmount == 0) revert Errors.SwapFailed();
        if (!IZRC20(targetTokenAddress).approve(targetTokenAddress, outputAmount)) revert Errors.ApprovalFailed();

        uint256 feeAmount = outputAmount * platformFee / 10000;
        uint256 newAmount = outputAmount - feeAmount;

        if (feeAmount > 0) {
            TransferHelper.safeTransfer(targetTokenAddress, kyexTreasury, feeAmount);
        }

        bool transferSuccess = IZRC20(targetTokenAddress).transfer(bytesToAddress(recipientAddress, 0), newAmount);
        if (!transferSuccess) revert Errors.TransferFailed();

        emit WrappedTokenTransfer(amount, address(uint160(bytes20(recipientAddress))));
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
            bytes memory recipientAddress
        )
    {
        if (chainID == BITCOIN) {
            isWithdraw = BytesHelperLib.bytesToUint32(message, 3);
            slippage = BytesHelperLib.bytesToUint32(message, 7);
            targetTokenAddress = BytesHelperLib.bytesToAddress(message, 8);
            recipientAddress = abi.encodePacked(BytesHelperLib.bytesToAddress(message, 28));
        } else {
            (
                uint32 _isWithdraw,
                uint32 _slippage,
                address targetToken,
                bytes memory recipient
            ) = abi.decode(message, (uint32, uint32, address, bytes));
            targetTokenAddress = targetToken;
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
                systemContract, zrc20, swapAmounts.gasFee, swapAmounts.gasZRC20, newAmount, slippage, MAX_DEADLINE
            );
        }
        swapAmounts.outputAmount = SwapHelperLib.swapExactTokensForTokens(
            systemContract,
            zrc20,
            swapAmounts.isTargetZeta ? newAmount : newAmount - swapAmounts.inputForGas,
            targetTokenAddress,
            0,
            slippage,
            MAX_DEADLINE
        );
    }

    ///////////////////
    // receive
    ///////////////////
    receive() external payable {}
}
