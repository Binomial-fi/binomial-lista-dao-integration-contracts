// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin-upgradable/access/AccessControlUpgradeable.sol";
import "@openzeppelin-upgradable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin-upgradable/utils/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IListaIntegration} from "./interfaces/IListaIntegration.sol";
import {IHeliosProvider} from "./interfaces/IHeliosProvider.sol";
import {TransferHelper} from "./libs/TransferHelper.sol";
import {IWNomBnb} from "./interfaces/IWNomBnb.sol";
import {ISimpleStaking} from "./simple-staking/interfaces/ISimpleStaking.sol";

contract ListaIntegration is
    IListaIntegration,
    ERC20Upgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    address public HELIOS_PROVIDER;
    address public PROVIDE_DELEGATE_TO;
    address public SIMPLE_STAKING;
    address public BN_W_CLIS_BNB;

    // Rewards related
    address public FEE_RECEIVER;
    uint256 public FEE_PERC; // 1e20 == 100%
    uint256 public totalFees;
    uint256 public totalRewards;

    // Users
    mapping(uint256 => mapping(address => uint256)) public userRatio;
    mapping(address => uint256) public userRewards;
    mapping(address => uint256) public userLastDist;
    mapping(address => uint256) public userLastInteraction;

    // Distributions
    IListaIntegration.Distribution[] public distributions;

    function initialize(
        string memory _tokenName,
        string memory _tokenSymbol,
        address _heliosProvider,
        address _delegateTo,
        address _feeReceiver,
        uint256 _feePerc,
        address _simpleStaking,
        address _wnomBnb
    ) public initializer {
        __ERC20_init(_tokenName, _tokenSymbol);

        HELIOS_PROVIDER = _heliosProvider;
        PROVIDE_DELEGATE_TO = _delegateTo;
        SIMPLE_STAKING = _simpleStaking;
        BN_W_CLIS_BNB = _wnomBnb;

        FEE_RECEIVER = _feeReceiver;
        FEE_PERC = _feePerc;

        IListaIntegration.Distribution memory initialDistribution = IListaIntegration.Distribution({
            start: block.number,
            end: 0,
            rewards: 0,
            capitalLastRatio: 0,
            lastInteraction: block.number
        });
        distributions.push(initialDistribution);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        bool approveSuccess = IERC20(BN_W_CLIS_BNB).approve(SIMPLE_STAKING, type(uint256).max);
        if (!approveSuccess) revert ApproveFailed();

        emit FeeReceiverChanged(address(0), FEE_RECEIVER);
        emit FeePercentageChanged(0, FEE_PERC);
    }

    receive() external payable {}

    function stake() public payable nonReentrant {
        commitUser(msg.sender, distributions.length - 1);
        _updateCurrentRatio(msg.sender);

        IHeliosProvider.Delegation memory delegatedAmountBefore =
            IHeliosProvider(HELIOS_PROVIDER)._delegation(address(this));

        // Provide to HeliosProviderV2
        IHeliosProvider(HELIOS_PROVIDER).provide{value: msg.value}(PROVIDE_DELEGATE_TO);

        IHeliosProvider.Delegation memory delegatedAmountAfter =
            IHeliosProvider(HELIOS_PROVIDER)._delegation(address(this));

        uint256 providedAmount = delegatedAmountAfter.amount - delegatedAmountBefore.amount;

        // Mint LRS to user
        _mint(msg.sender, providedAmount);

        // Mint WNomBnb and stake it in simple staking
        IWNomBnb(BN_W_CLIS_BNB).mint(address(this), providedAmount);
        ISimpleStaking(SIMPLE_STAKING).stake(BN_W_CLIS_BNB, providedAmount);

        // Emit event
        emit IListaIntegration.Stake(
            msg.sender,
            address(0), // Native currency
            msg.value,
            block.timestamp,
            providedAmount
        );
    }

    function unstake(uint256 _amount) public nonReentrant {
        if (_amount == 0) revert InvalidAmount();
        if (_amount > balanceOf(msg.sender)) revert InsufficientBalance();

        commitUser(msg.sender, distributions.length - 1);
        _updateCurrentRatio(msg.sender);

        // Unstake WNomBnb and burn it
        uint256 wnomBnbBefore = IERC20(BN_W_CLIS_BNB).balanceOf(address(this));
        ISimpleStaking(SIMPLE_STAKING).unstake(BN_W_CLIS_BNB, _amount);
        uint256 wnomBnbAfter = IERC20(BN_W_CLIS_BNB).balanceOf(address(this));
        if (wnomBnbAfter - wnomBnbBefore != _amount) {
            revert UnstakeAmountMismatch();
        }
        IWNomBnb(BN_W_CLIS_BNB).burn(address(this), _amount);

        // Burn LRS - we burn the passed amount
        _burn(msg.sender, _amount);

        // Release from HeliosProviderV2
        uint256 releasedAmount = IHeliosProvider(HELIOS_PROVIDER).release(msg.sender, _amount);
        if (releasedAmount == 0) revert ReleaseAmountZero();

        emit IListaIntegration.Unstake(msg.sender, address(0), _amount, block.timestamp, releasedAmount);
    }

    function unstakeLiquidBnb(uint256 _amount, address _asset) public nonReentrant {
        if (_amount == 0) revert InvalidAmount();
        if (_amount > balanceOf(msg.sender)) revert InsufficientBalance();
        if (_asset == address(0)) revert InvalidAsset();

        commitUser(msg.sender, distributions.length - 1);
        _updateCurrentRatio(msg.sender);

        // Unstake WNomBnb and burn it
        uint256 wnomBnbBefore = IERC20(BN_W_CLIS_BNB).balanceOf(address(this));
        ISimpleStaking(SIMPLE_STAKING).unstake(BN_W_CLIS_BNB, _amount);
        uint256 wnomBnbAfter = IERC20(BN_W_CLIS_BNB).balanceOf(address(this));
        if (wnomBnbAfter - wnomBnbBefore != _amount) {
            revert UnstakeAmountMismatch();
        }
        IWNomBnb(BN_W_CLIS_BNB).burn(address(this), _amount);

        // Burn LRS - we burn the passed amount
        _burn(msg.sender, _amount);

        // Release from HeliosProviderV2
        uint256 releasedAmount = IHeliosProvider(HELIOS_PROVIDER).releaseInToken(_asset, msg.sender, _amount);
        if (releasedAmount == 0) revert ReleaseAmountZero();

        emit IListaIntegration.Unstake(msg.sender, _asset, _amount, block.timestamp, releasedAmount);
    }

    // Claim rewards
    function claimRewards() public nonReentrant {
        commitUser(msg.sender, distributions.length - 1);
        uint256 rewardsToClaim = userRewards[msg.sender];
        if (rewardsToClaim == 0) revert IListaIntegration.ClaimFailed();

        totalRewards -= rewardsToClaim;
        userRewards[msg.sender] = 0;

        TransferHelper.safeTransferNative(msg.sender, rewardsToClaim);

        emit IListaIntegration.ClaimedRewards(msg.sender, rewardsToClaim, userLastDist[msg.sender]);
    }

    // Sync rewards for use from userLastDist[_account] until _distIndex
    function commitUser(address _account, uint256 _distIndex) public {
        if (_distIndex > distributions.length - 1 || _distIndex < userLastDist[_account]) {
            revert ProvidedIndexNotCorrect();
        }

        for (uint256 distIndex = userLastDist[_account]; distIndex < _distIndex;) {
            IListaIntegration.Distribution storage targetDist = distributions[distIndex];

            userRatio[distIndex][_account] = (targetDist.end - userLastInteraction[_account])
                * super.balanceOf(_account) + userRatio[distIndex][_account];
            userLastInteraction[_account] = targetDist.end;
            userRewards[_account] += (userRatio[distIndex][_account] * targetDist.rewards) / targetDist.capitalLastRatio;
            unchecked {
                distIndex++;
            }
        }

        userLastDist[_account] = _distIndex;
    }

    function transferFrom(address _from, address _to, uint256 _value) public override returns (bool) {
        commitUser(_from, distributions.length - 1);
        _updateCurrentRatio(_from);

        commitUser(_to, distributions.length - 1);
        _updateCurrentRatio(_to);

        super.transfer(_to, _value);
        return true;
    }

    function transfer(address _to, uint256 _value) public override returns (bool) {
        commitUser(_to, distributions.length - 1);
        _updateCurrentRatio(_to);

        commitUser(msg.sender, distributions.length - 1);
        _updateCurrentRatio(msg.sender);

        super.transfer(_to, _value);
        return true;
    }

    function getDistId() public view returns (uint256) {
        return distributions.length - 1;
    }

    // ================== A D M I N ================== //
    function createDistribution() public onlyRole(ADMIN_ROLE) {
        // Update current distribution
        IListaIntegration.Distribution storage currentDistribution = distributions[distributions.length - 1];
        uint256 incomingRewards = address(this).balance - (totalFees + totalRewards);
        uint256 incomingFees = (incomingRewards * FEE_PERC) / 1e20;

        totalFees += incomingFees;
        totalRewards += incomingRewards - incomingFees;

        currentDistribution.rewards = incomingRewards - incomingFees;
        currentDistribution.end = block.number;
        currentDistribution.capitalLastRatio =
            (block.number - currentDistribution.lastInteraction) * totalSupply() + currentDistribution.capitalLastRatio;

        // create new distribution
        IListaIntegration.Distribution memory newDistribution = IListaIntegration.Distribution({
            start: block.number,
            end: 0,
            rewards: 0,
            capitalLastRatio: 0,
            lastInteraction: block.number
        });
        distributions.push(newDistribution);

        emit NewDistribution(distributions.length - 1, newDistribution.start);
    }

    function claimFees() public nonReentrant onlyRole(ADMIN_ROLE) {
        TransferHelper.safeTransferNative(FEE_RECEIVER, totalFees);

        totalFees = 0;

        emit IListaIntegration.ClaimedAdminFees(FEE_RECEIVER, totalFees);
    }

    function setFeeReceiver(address _newReceiver) public onlyRole(ADMIN_ROLE) {
        address oldReceiver = FEE_RECEIVER;
        FEE_RECEIVER = _newReceiver;

        emit FeeReceiverChanged(oldReceiver, _newReceiver);
    }

    function setFeePerc(uint256 _newPerc) public onlyRole(ADMIN_ROLE) {
        if (_newPerc > 1e20) {
            revert InvalidPercentage();
        }
        uint256 oldPercentage = FEE_PERC;
        FEE_PERC = _newPerc;

        emit FeePercentageChanged(oldPercentage, _newPerc);
    }

    // ================== I N T E R N A L ================== //
    function _updateCurrentRatio(address _account) internal {
        uint256 distributionsLength = distributions.length - 1;

        // Update capital ratio
        IListaIntegration.Distribution storage targetDist = distributions[distributionsLength];
        targetDist.capitalLastRatio =
            (block.number - targetDist.lastInteraction) * totalSupply() + targetDist.capitalLastRatio;
        targetDist.lastInteraction = block.number;

        userRatio[distributionsLength][_account] = (block.number - userLastInteraction[_account])
            * super.balanceOf(_account) + userRatio[distributionsLength][_account];
        userLastInteraction[_account] = block.number;
    }
}
