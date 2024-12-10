// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ICollateral {
    function balanceOf(address account) external returns (uint256);
    function decimals() external returns (uint8);
    function symbol() external returns (string memory);
}
