// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IListaIntegration {
    error ClaimFailed();
    error InvalidPercentage();
    error ProvidedIndexNotCorrect();

    event Stake(address _sender, address _token, uint256 _amount, uint256 _blockTimestamp);
    event Unstake(address _sender, uint256 _amount, address _token);
    event ClaimedAdminFees(address _receiver, uint256 _amount);
    event ClaimedRewards(address _account, uint256 _rewards, uint256 _distIndex);
    event NewDistribution(uint256 _distributionId, uint256 _startBlock);
    event FeeReceiverChanged(address _oldReceiver, address _newReceiver);
    event FeePercentageChanged(uint256 _oldPercentage, uint256 _newPercentage);

    struct Distribution {
        uint256 start;
        uint256 end;
        uint256 rewards;
        uint256 capitalLastRatio;
        uint256 lastInteraction; // block number
    }

    // Public functions
    function stake() external payable;
    function unstake(uint256 _amount) external;
    function unstakeLiquidBnb(uint256 _amount, address _asset) external;
    function claimRewards() external;
    function commitUser(address _account, uint256 _distIndex) external;

    // Admin functions
    function createDistribution() external;
    function claimFees() external;
    function setFeeReceiver(address _newReceiver) external;
    function setFeePerc(uint256 _newPerc) external;
}
