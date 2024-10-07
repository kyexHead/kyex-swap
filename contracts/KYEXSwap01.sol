// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "libraries/UniswapV2Library.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "libraries/zetaV2/interfaces/IZRC20.sol";
import "libraries/zetaV2/interfaces/IWZETA.sol";
import "libraries/TransferHelper.sol";
import "libraries/error/Errors.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "libraries/zetaV2/Zeta.eth.sol";
import "libraries/zetaV2/ZetaInteractor.sol";
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
 * @title KYEX ZRC Swap
 * @author KYEX-TEAM
 * @notice KYEX Mainnet ZETACHAIN zrcSwap Smart Contract V1
 */
contract KYEXSwap01 is UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable {
    ///////////////////
    // State Variables
    ///////////////////
    address private WZETA; // Note:when deploying on the mainnet，This should be changed to 【 address public constant WZETA = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf; 】
    address public constant BITCOIN = 0x13A0c5930C028511Dc02665E7285134B6d11A5f4; // Note:when deploying on the testnet，This should be changed to 【 address public constant BITCOIN = 0x65a45c57636f9BcCeD4fe193A602008578BcA90b; 】

    address private UniswapRouter;
    address private UniswapFactory;
    address private kyexTreasury;
    uint32 private MAX_DEADLINE;
    uint16 private MAX_SLIPPAGE;
    uint256 public volume;
    uint16 private platformFee;
    ZetaConnector public connector;

    ///////////////////
    // Events
    ///////////////////
    event SwapExecuted(address indexed sender, address tokenA, address tokenB, uint256 amountA, uint256 amountB);
    event PerformSwap(address tokenA, address tokenB, uint256 amountIn, uint256 amountOut);
    event ZETAWrapped(address indexed sender, uint256 amount);
    event TokenTransfer(address indexed sender, uint256 amount);
    event ZETAWithdrawn(address indexed owner, uint256 amount);

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
        uint16 _MAX_SLIPPAGE,
        address connectorAddress_

    ) external initializer {
        __Ownable_init();
        __Pausable_init();

        WZETA = _WZETA; //Note: when deploying on the mainnet，this line should be deleted.
        UniswapRouter = _UniswapRouter;
        UniswapFactory = _UniswapFactory;
        kyexTreasury = _kyexTreasury;
        MAX_DEADLINE = _MAX_DEADLINE;
        platformFee = _platformFee;
        MAX_SLIPPAGE = _MAX_SLIPPAGE;
        volume = 0;
        connector = ZetaConnector(connectorAddress_);

        // Initializable._disableInitializers(); 
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

    /**
     * @dev To check for existing pairing
     */
    function checkPairExists(address tokenA, address tokenB) public view returns (bool) {
        address pairAddress = IUniswapV2Factory(UniswapFactory).getPair(tokenA, tokenB);
        return pairAddress != address(0); // True if the pair exists, false otherwise
    }

    /**
     * @dev To get reserves of the pairing pool
     */
    function getReserves(address tokenIn, address tokenOut) public view returns (uint, uint) {
        (uint reserveA, uint reserveB)= UniswapV2Library.getReserves(UniswapFactory, tokenIn, tokenOut);
        return (reserveA, reserveB);
    }

    /**
     * @dev Transfer WZETA to other native chain.
     */
    function transferZETAout(
        uint256 destinationChainId,
        bytes memory destinationAddress,
        uint256 destinationAmount
    ) public payable {

        TransferHelper.safeApprove(WZETA, address(connector), destinationAmount);
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
    // External Function
    ///////////////////

    /**
     * @dev Withdraw ZETA from the contract, only the owner can execute this operation
     */
    function withdrawZETA() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert Errors.InsufficientFunds();

        (bool success,) = owner().call{value: balance}("");
        if (!success) revert Errors.TransferFailed();

        emit ZETAWithdrawn(owner(), balance);
    }

    /**
     * @dev Swap tokens from ZetaChain to any other chain
     *
     * @param tokenInOfZetaChain: The tokenIn address of ZetaChain (WZETA or ZRC20)
     * @param tokenOutOfZetaChain: The tokenOut address of ZetaChain
     * @param amountIn: The amount of tokenIn
     * @param isWrap: Is it a wrapped token?
     * @param btcRecipient: The address of BTC receiving
     * @param slippageTolerance: The maximum slippage you allow
     * @param isCrossChain: Whether to perform a cross-chain swap?
     * eg: tokenInOfZetaChain: Zeta.WETA, tokenOutOfZetaChain: Zeta.USDC(ETH)
     *     isCrossChain = false: Zeta.WETA >>>>> Zeta.USDC(ETH)
     *     isCrossChain = true: Zeta.WETA >>>>> Zeta.USDC(ETH) >>>>> ETH.USDC
     */
    function zrcSwapToNative(
        address tokenInOfZetaChain,
        address tokenOutOfZetaChain,
        uint256 amountIn,
        bool isWrap,
        bytes memory btcRecipient,
        uint16 slippageTolerance,
        bool isCrossChain,
        uint8 chainId
    ) external payable whenNotPaused {
        uint256 amountOut;
        address gasZRC20;

        // Each ZRC20 has the ‘CHAIN_ID’ variable, and ZRC20 tokens from the same native chain share the same 'CHAIN_ID'
        // The 'gasZRC20' for each chain is set in ZetaChain's SystemContract.(its mainnet address is `0x91d18e54daf4f677cb28167158d6dd21f6ab3921`)
        // eg: 1. tokenOutOfZetaChain = Zeta.USDC(ETH), gasZRC20 = Zeta.ETH(ETH)
        //     2. tokenOutOfZetaChain = Zeta.ETH(ETH), gasZRC20 = Zeta.ETH(ETH)
        //
        if (tokenOutOfZetaChain != WZETA) {
            (gasZRC20,) = IZRC20(tokenOutOfZetaChain).withdrawGasFee();
        } else {
            gasZRC20 = WZETA;
        }

        if (tokenOutOfZetaChain != gasZRC20 && tokenOutOfZetaChain != BITCOIN) {
            // tokenOutOfZetaChain is not equals to gasZRC20
            // eg: tokenOutOfZetaChain = Zeta.USDC(ETH), gasZRC20 = Zeta.ETH(ETH)
            amountOut =
                withdrawERC(tokenInOfZetaChain, tokenOutOfZetaChain, amountIn, isWrap, slippageTolerance, isCrossChain);
        } else {
            // tokenOutOfZetaChain is equals to gasZRC20
            // eg: 1. tokenOutOfZetaChain = Zeta.WZETA, gasZRC20 = Zeta.WZETA
            //     2. tokenOutOfZetaChain = Zeta.BTC, gasZRC20 = Zeta.BTC
            //     3. tokenOutOfZetaChain = Zeta.ETH(ETH), gasZRC20 = Zeta.ETH(ETH)
            amountOut = swapTokens(tokenInOfZetaChain, tokenOutOfZetaChain, amountIn, isWrap, slippageTolerance);

            if (tokenOutOfZetaChain == WZETA) {
                transferTokens(tokenOutOfZetaChain, msg.sender, amountOut, isWrap, isCrossChain, chainId);
            } else if (tokenOutOfZetaChain == BITCOIN) {
                withdrawOther(tokenOutOfZetaChain, btcRecipient, amountOut, isCrossChain);
            } else if (tokenOutOfZetaChain == gasZRC20) {
                withdrawOther(tokenOutOfZetaChain, abi.encodePacked(msg.sender), amountOut, isCrossChain); 
            }
        }
        (tokenInOfZetaChain == WZETA) ? volume += amountIn : volume += getZetaQuote(tokenInOfZetaChain, WZETA, amountIn);
        emit SwapExecuted(msg.sender, tokenInOfZetaChain, tokenOutOfZetaChain, amountIn, amountOut);
    }
    /**
     * @dev update config
     */

    function updateConfig(uint16 _slippage, uint16 _newFee, address _newAddress) external onlyOwner {
        MAX_SLIPPAGE = _slippage;
        platformFee = _newFee;
        kyexTreasury = _newAddress;
    }

    function getPlatformFee() external view returns (uint256) {
        return platformFee;
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
        (uint256 reserveA, uint256 reserveB) = UniswapV2Library.getReserves(UniswapFactory, tokenIn, tokenOut);
        amount = UniswapV2Library.quote(amountIn, reserveA, reserveB);
    }

    /**
     * @dev Helper functions to calculate minimum output amounts based on slippage tolerance
     */
    function calculateMinimumOutputAmount(uint256 amountIn, address[] memory path, uint256 slippageTolerance)
        internal
        view
        returns (uint256)
    {
        uint256[] memory amountsOut = IUniswapV2Router02(UniswapRouter).getAmountsOut(amountIn, path);
        return amountsOut[amountsOut.length - 1] * (1000 - slippageTolerance) / 1000;
    }

    /**
     * @dev Helper functions to calculate maximum input amounts based on slippage tolerance
     */
    function calculateMaximumInputAmount(uint256 amountOut, address[] memory path, uint256 slippageTolerance)
        internal
        view
        returns (uint256)
    {
        uint256[] memory amountsIn = IUniswapV2Router02(UniswapRouter).getAmountsIn(amountOut, path);
        return amountsIn[0] * (1000 + slippageTolerance) / 1000;
    }

    function sendZETA(address tokenA, uint256 amount, bool isWrap) internal returns (uint256) {
        if (tokenA != WZETA) revert Errors.OnlySupportZETA();
        if (amount == 0) revert Errors.NeedsMoreThanZero();

        // tZETA
        if (!isWrap) {
            if (msg.value != amount) revert Errors.IncorrectAmountOfZETASent();
            if (address(this).balance < amount) revert Errors.InsufficientFunds();

            IWETH9(WZETA).deposit{value: amount}();
            amount = IWETH9(WZETA).balanceOf(address(this));
            if (!IWETH9(WZETA).approve(UniswapRouter, amount)) revert Errors.ApprovalFailed();
            emit ZETAWrapped(msg.sender, amount);
        } else {
            if (IWETH9(WZETA).allowance(msg.sender, address(this)) < amount) {
                revert Errors.InsufficientAllowance();
            }

            TransferHelper.safeTransferFrom(WZETA, msg.sender, address(this), amount);
            amount = IWETH9(WZETA).balanceOf(address(this));

            if (!IWETH9(WZETA).approve(UniswapRouter, amount)) revert Errors.ApprovalFailed();
            emit TokenTransfer(msg.sender, amount);
        }

        return amount;
    }

    function withdrawERC(
        address tokenA,
        address tokenB,
        uint256 amountIn,
        bool isWrap,
        uint256 slippageTolerance,
        bool isCrossChain
    ) internal returns (uint256) {
        if (amountIn == 0) revert Errors.NeedsMoreThanZero();
        if (slippageTolerance > MAX_SLIPPAGE) revert Errors.SlippageToleranceExceedsMaximum();

        address[] memory path;
        uint256[] memory amount;
        uint256 newAmount;

        (address gasZRC20, uint256 gasFee) = IZRC20(tokenB).withdrawGasFee();
        if (gasFee < 0) revert Errors.InsufficientGasForWithdraw(); 

        if (tokenA == WZETA) {
            amountIn = sendZETA(tokenA, amountIn, isWrap);
        } else {
            // Ensure the user has approved the contract to spend the tokens

            if (IZRC20(tokenA).allowance(msg.sender, address(this)) < amountIn) {
                revert Errors.InsufficientAllowance();
            }

            TransferHelper.safeTransferFrom(tokenA, msg.sender, address(this), amountIn);
            TransferHelper.safeApprove(tokenA, UniswapRouter, amountIn);

            path = new address[](2);
            path[0] = tokenA;
            path[1] = WZETA;

            // Swap tokenA to WZETA
            amount = IUniswapV2Router02(UniswapRouter).swapExactTokensForTokens(
                amountIn,
                calculateMinimumOutputAmount(amountIn, path, slippageTolerance),
                path,
                address(this),
                block.timestamp + MAX_DEADLINE
            );
            if (amount[1] == 0) revert Errors.SwapFailed();
            TransferHelper.safeApprove(WZETA, UniswapRouter, amount[1]);
            amountIn = amount[1];
        }

        newAmount = handleWithdraw(tokenB, isCrossChain, gasZRC20, gasFee, amountIn, slippageTolerance);

        return newAmount;
    }

    function handleWithdraw(
        address tokenB,
        bool isCrossChain,
        address gasZRC20,
        uint256 gasFee,
        uint256 newAmount,
        uint256 slippageTolerance
    ) internal returns (uint256) {
        address[] memory path = new address[](2);

        if (isCrossChain == true) {
            // Swap WZETA to gasZRC20 for the gas fee
            path[0] = WZETA;
            path[1] = gasZRC20;

            uint256[] memory inputForGas = IUniswapV2Router02(UniswapRouter).swapTokensForExactTokens(
                gasFee,
                calculateMaximumInputAmount(gasFee, path, slippageTolerance),
                path,
                address(this),
                block.timestamp + MAX_DEADLINE
            );

            if (inputForGas[0] == 0) revert Errors.SwapFailed();

            uint256 remainingAmount = IWETH9(WZETA).balanceOf(address(this));

            // Swap remaining WZETA to tokenB
            path[0] = WZETA;
            path[1] = tokenB;

            newAmount = handleExactTokensForTokens(remainingAmount, path, MAX_DEADLINE, slippageTolerance);

            TransferHelper.safeApprove(gasZRC20, tokenB, gasFee);
            IZRC20(tokenB).withdraw(abi.encodePacked(msg.sender), newAmount);

        } else {
            // Swap remaining WZETA to tokenB
            path[0] = WZETA;
            path[1] = tokenB;

            newAmount = handleExactTokensForTokens(newAmount, path, MAX_DEADLINE, slippageTolerance);
            TransferHelper.safeTransfer(tokenB, msg.sender, newAmount);
        }
        return newAmount;
    }

    function handleExactTokensForTokens(
        uint256 amountIn,
        address[] memory path,
        uint256 deadline,
        uint256 slippageTolerance
    ) internal returns (uint256) {
        uint256[] memory amountOut = IUniswapV2Router02(UniswapRouter).swapExactTokensForTokens(
            amountIn,
            calculateMinimumOutputAmount(amountIn, path, slippageTolerance),
            path,
            address(this),
            block.timestamp + deadline
        );
        if (amountOut[1] == 0) revert Errors.SwapFailed();

        return amountOut[1];
    }

    function swapTokens(address tokenA, address tokenB, uint256 amountA, bool isWrap, uint256 slippageTolerance)
        internal
        returns (uint256)
    {
        if (amountA == 0) revert Errors.NeedsMoreThanZero();

        if (platformFee > 9999) revert Errors.PlatformFeeNeedslessThanOneHundredPercent();
        if (slippageTolerance > MAX_SLIPPAGE) revert Errors.SlippageToleranceExceedsMaximum();

        uint256 amountOut;

        // tZETA || wZETA
        if (tokenA == WZETA) {
            sendZETA(tokenA, amountA, isWrap);

            // !zetaToken
        } else {
            // Ensure the user has approved the contract to spend the tokens
            if (IZRC20(tokenA).allowance(msg.sender, address(this)) < amountA) {
                revert Errors.InsufficientAllowance();
            }
            TransferHelper.safeTransferFrom(tokenA, msg.sender, address(this), amountA);
            TransferHelper.safeApprove(tokenA, UniswapRouter, amountA);
        }

        address[] memory path;
        address pairAddress = IUniswapV2Factory(UniswapFactory).getPair(tokenA, tokenB);
        if (pairAddress != address(0)) {
            path = new address[](2);
            path[0] = tokenA;
            path[1] = tokenB;

            uint256[] memory amounts = IUniswapV2Router02(UniswapRouter).swapExactTokensForTokens(
                amountA,
                calculateMinimumOutputAmount(amountA, path, slippageTolerance),
                path,
                address(this),
                block.timestamp + MAX_DEADLINE
            );

            amountOut = amounts[1];
        } else {
            path = new address[](3);
            path[0] = tokenA;
            path[1] = WZETA;
            path[2] = tokenB;

            uint256[] memory amounts = IUniswapV2Router02(UniswapRouter).swapExactTokensForTokens(
                amountA,
                calculateMinimumOutputAmount(amountA, path, slippageTolerance),
                path,
                address(this),
                block.timestamp + MAX_DEADLINE
            );

            amountOut = amounts[2];
        }
        
        emit PerformSwap(tokenA, tokenB, amountA, amountOut);
        return amountOut;
    }

    function withdrawOther(address token, bytes memory recipient, uint256 amount, bool isWithdraw) internal {

        (address gasZRC20, uint256 gasFee) = IZRC20(token).withdrawGasFee();
        if (gasFee < 0) revert Errors.InsufficientGasForWithdraw(); 
        TransferHelper.safeApprove(gasZRC20, token, gasFee);
        if (amount < gasFee) revert Errors.InsufficientFunds();

        /*
            Transfer platformFee 
        */
        if (amount == 0) revert Errors.TransferFailed();
        uint256 feeAmount = (amount-gasFee) * platformFee / 10000;
        uint256 newAmount = (amount-gasFee) - feeAmount;

        if (feeAmount > 0) {
            TransferHelper.safeTransfer(token, kyexTreasury, feeAmount);
        }

        if (isWithdraw) {
            IZRC20(token).withdraw(recipient, newAmount - gasFee);
        } else {
            TransferHelper.safeTransfer(token, msg.sender, newAmount);
        }

    }

    function transferTokens(address tokenAddress, address recipient, uint256 amount, bool isWrap, bool isCrossChain, uint8 chainId) internal {

        /*
            Transfer platformFee 
        */
        if (amount == 0) revert Errors.TransferFailed();
        uint256 feeAmount = amount * platformFee / 10000;
        uint256 newAmount = amount - feeAmount;

        if (feeAmount > 0) {
            TransferHelper.safeTransfer(tokenAddress, kyexTreasury, feeAmount);
        }

        // Transfer WZETA to other native network
        if (isCrossChain && tokenAddress == WZETA) {
            transferZETAout(chainId, abi.encodePacked(recipient), newAmount);
        } else if (isWrap) {
            if (newAmount == 0) revert Errors.TransferFailed();
            TransferHelper.safeTransfer(tokenAddress, recipient, newAmount);
        } else { // !isWrap
            // Withdraw WZETA to tZETA
            // Send tZETA to recipient
            IWETH9(tokenAddress).withdraw(newAmount);
            (bool sent,) = recipient.call{value: newAmount}("");
            if (!sent) revert Errors.TransferFailed();
        }

        emit TokenTransfer(recipient, newAmount); // No need to convert recipient to address 
    }

    ///////////////////
    // receive
    ///////////////////
    receive() external payable {}
}
