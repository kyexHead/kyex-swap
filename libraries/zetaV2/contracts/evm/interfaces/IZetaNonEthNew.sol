// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IZetaNonEthNew
/// @notice IZetaNonEthNew is a mintable / burnable version of IERC20.
interface IZetaNonEthNew is IERC20 {
    /// @notice Burns the specified amount of tokens from the specified account.
    /// @param account The address of the account from which tokens will be burned.
    /// @param amount The amount of tokens to burn.
    /// @dev Emits a {Transfer} event with `to` set to the zero address.
    function burnFrom(address account, uint256 amount) external;

    /// @notice Mints the specified amount of tokens to the specified account.
    /// @param mintee The address of the account to which tokens will be minted.
    /// @param value The amount of tokens to mint.
    /// @param internalSendHash A hash used for internal tracking of the minting transaction.
    /// @dev Emits a {Transfer} event with `from` set to the zero address.
    function mint(address mintee, uint256 value, bytes32 internalSendHash) external;
}
