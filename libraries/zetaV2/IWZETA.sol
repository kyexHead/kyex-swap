// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IWETH9
/// @notice Interface for the Weth9 contract.
interface IWETH9 {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 wad) external returns (bool);

    function transfer(address to, uint256 wad) external returns (bool);

    function transferFrom(address from, address to, uint256 wad) external returns (bool);

    function deposit() external payable;

    function withdraw(uint256 wad) external;
}
