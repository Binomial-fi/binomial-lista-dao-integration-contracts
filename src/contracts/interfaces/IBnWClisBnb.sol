// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IBnWClisBnb {
    function mint(address _account, uint256 _amount) external;
    function burn(address _account, uint256 _amount) external;
}
