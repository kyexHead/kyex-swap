// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "libraries/pancake/IPancakeRouter02.sol";
import "libraries/pancake/IPancakeFactory.sol";
import "libraries/IWETH.sol";
import "libraries/TransferHelper.sol";
import "libraries/error/Errors.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract KYEXSwapBscV1 is
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    address private ZETA_BSC;
    address private BNB_BSC;
    uint256 private BNB_GAS;
    address private router;
    address private factory;
    uint32 private MAX_DEADLINE;

    event SwapExecuted(
        address indexed gameFiToken,
        address indexed recipeint,
        bytes32 indexed OriginTxHash,
        uint256 amount
    );

    event BNBWithdrawn(address indexed owner, uint256 amount);
    event ZETAWithdrawn(address indexed owner, uint256 amount);

    function initialize(
        uint32 _MAX_DEADLINE,
        address _factory,
        address _router,
        address _ZETA_BSC,
        address _BNB_BSC,
        uint256 _BNB_GAS
    ) external initializer {
        __Ownable_init();
        __Pausable_init();

        MAX_DEADLINE = _MAX_DEADLINE;
        factory = _factory;
        router = _router;
        ZETA_BSC = _ZETA_BSC;
        BNB_BSC = _BNB_BSC;
        BNB_GAS = _BNB_GAS;
    }

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

    function withdrawBNB() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert Errors.InsufficientFunds();
        TransferHelper.safeTransferZETA(owner(), balance);

        emit BNBWithdrawn(owner(), balance);
    }

    function withdrawZETA() external onlyOwner {
        uint256 balance = IERC20(ZETA_BSC).balanceOf(address(this));
        if (balance == 0) revert Errors.InsufficientFunds();
        TransferHelper.safeTransfer(ZETA_BSC, owner(), balance);

        emit ZETAWithdrawn(owner(), balance);
    }

    function onReceiveSwap(
        address tokenOut,
        address recipientAddress,
        uint256 amountIn,
        bytes32 originTxHash
    ) external whenNotPaused {
        // 1. Swap: WZETA -> BNB
        TransferHelper.safeApprove(ZETA_BSC, router, amountIn);
        address[] memory newPath = new address[](2);
        newPath[0] = ZETA_BSC;
        newPath[1] = BNB_BSC;
        uint256[] memory outputAmount = IPancakeRouter02(router)
            .swapExactTokensForTokens(
                amountIn,
                0,
                newPath,
                address(this),
                block.timestamp + MAX_DEADLINE
            );

        // 2. Deduct swapTxGasUsed from sender
        uint256 newAmount = outputAmount[1] - BNB_GAS;
        if (newAmount == 0) revert Errors.InsufficientFunds();

        // 3. Swap: WETH -> gameFi
        newPath[0] = BNB_BSC;
        newPath[1] = tokenOut;
        TransferHelper.safeApprove(BNB_BSC, router, newAmount);

        outputAmount = IPancakeRouter02(router).swapExactTokensForTokens(
            newAmount,
            0,
            newPath,
            address(this),
            block.timestamp + MAX_DEADLINE
        );

        // 4. Transfer to recipient
        TransferHelper.safeTransfer(
            tokenOut,
            recipientAddress,
            outputAmount[1]
        );

        emit SwapExecuted(
            tokenOut,
            recipientAddress,
            originTxHash,
            outputAmount[1]
        );
    }

    // // **** SWAP (supporting fee-on-transfer tokens) ****
    // // requires the initial amount to have already been sent to the first pair

    // function swapExactTokensForEthToZeta(
    //     uint amountIn,
    //     address[] calldata path,
    //     uint deadline,
    //     bytes calldata message
    // ) external {
    //     // 1. Swap: token A -> WETH
    //     address[] memory newPath = new address[](2);
    //     newPath[0] = path[0];
    //     newPath[1] = WETH;

    //     TransferHelper.safeTransferFrom(
    //         newPath[0],
    //         msg.sender,
    //         PancakeLibrary.pairFor(factory, newPath[0], newPath[1]),
    //         amountIn
    //     );
    //     pancakeRouter._swapSupportingFeeOnTransferTokens(
    //         newPath,
    //         address(this)
    //     );

    //     // 2. Swap: WETH -> token B
    //     uint amountOut = IERC20(WETH).balanceOf(address(this));
    //     newPath[0] = WETH;
    //     newPath[1] = path[1];

    //     TransferHelper.safeTransfer(
    //         newPath[0],
    //         PancakeLibrary.pairFor(factory, newPath[0], newPath[1]),
    //         amountOut
    //     );
    //     pancakeRouter._swapSupportingFeeOnTransferTokens(
    //         newPath,
    //         address(this)
    //     );

    //     // 3. Deposit final output (token B) to zetachain
    //     amountOut = IERC20(path[1]).balanceOf(address(this));
    //     IERC20(path[1]).approve(address(erc20Custody), amountOut);
    //     erc20Custody.deposit(
    //         abi.encodePacked(msg.sender),
    //         IERC20(path[1]),
    //         amountOut,
    //         message
    //     );

    //     // TransferHelper.safeTransfer(path[1], msg.sender, amountOut);
    // }

    // function bytesToAddress(
    //     bytes memory data,
    //     uint256 offset
    // ) internal pure returns (address output) {
    //     bytes memory b = new bytes(20);
    //     for (uint256 i = 0; i < 20; i++) {
    //         b[i] = data[i + offset];
    //     }
    //     assembly {
    //         output := mload(add(b, 20))
    //     }
    // }
    function _authorizeUpgrade(address) internal override onlyOwner {}

    receive() external payable {}
}
