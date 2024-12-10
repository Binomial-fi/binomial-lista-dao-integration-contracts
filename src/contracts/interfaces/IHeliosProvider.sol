// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IHeliosProvider {
    struct Delegation {
        address delegateTo; // who helps delegator to hold clisBNB, aka the delegatee
        uint256 amount;
    }

    function _delegation(address _account) external returns (Delegation memory);
    function _collateralToken() external returns (address);

    function provide(address _delegateTo) external payable returns (uint256 value);
    function release(address _recipient, uint256 _amount) external returns (uint256 realAmount);
    function releaseInToken(address _token, address _recipient, uint256 _amount)
        external
        returns (uint256 realAmount);
}
