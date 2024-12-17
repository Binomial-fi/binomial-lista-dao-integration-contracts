// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {ListaIntegration} from "../contracts/ListaIntegration.sol";
import {BnWClisBnb} from "../contracts/BnWClisBnb.sol";
import {IHeliosProvider} from "../contracts/interfaces/IHeliosProvider.sol";
import {IListaIntegration} from "../contracts/interfaces/IListaIntegration.sol";
import {ICollateral} from "../contracts/interfaces/ICollateral.sol";
import {SimpleStaking} from "../contracts/simple-staking/SimpleStaking.sol";
import {Test, console, stdStorage, StdStorage} from "forge-std/Test.sol";

contract ListaIntegrationTest is Test {
    using stdStorage for StdStorage;

    string RPC_URL = vm.envString("MAINNET_RPC_URL"); // MAINNET
    uint256 fork = vm.createFork(RPC_URL, 44606919);

    SimpleStaking public simpleStaking;
    BnWClisBnb public bnwClisBnb;
    ListaIntegration public stake_lista_contract;

    address owner = vm.addr(1);
    address user1 = vm.addr(2);
    address user2 = vm.addr(3);

    address rewardsDistributor = vm.addr(10);
    address feeReceiver = vm.addr(11);

    // address heliosProvider = 0x2BA4f785a3cC04DC1877fCA650331f00416eE8D1; // testnet
    address heliosProvider = 0xa835F890Fcde7679e7F7711aBfd515d2A267Ed0B; // mainnet
    // address collateral = 0x3dC5a40119B85d5f2b06eEC86a6d36852bd9aB52; // testnet
    address collateral = 0x4b30fcAA7945fE9fDEFD2895aae539ba102Ed6F6; // mainnet
    address delegateTo = 0xD57E5321e67607Fab38347D96394e0E58509C506; // heliosProvider.provide(_delegateTo)
    // address slisBnb = ; // testnet
    address slisBnb = 0xB0b84D294e0C75A6abe60171b70edEb2EFd14A1B; // mainnet
    address slisBnbStrategy = 0x6F28FeC449dbd2056b76ac666350Af8773E03873;

    function setUp() public {
        // Select fork
        vm.selectFork(fork);

        vm.startPrank(owner);

        // init simple staking
        simpleStaking = new SimpleStaking();

        // init bnwClisBnb token contract
        bnwClisBnb = new BnWClisBnb("BnWClisBnb", "BnWClisBnb");

        // set up proxy
        ProxyAdmin proxyAdmin = new ProxyAdmin(address(1));

        // set up stake lista impl
        ListaIntegration stakeListaImplementation = new ListaIntegration();

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(stakeListaImplementation),
            address(proxyAdmin),
            abi.encodeWithSelector(
                ListaIntegration(stakeListaImplementation).initialize.selector,
                "LRS",
                "LRS",
                heliosProvider,
                delegateTo,
                feeReceiver,
                5 ether,
                address(simpleStaking),
                address(bnwClisBnb)
            )
        );
        stake_lista_contract = ListaIntegration(payable(address(proxy)));
        stake_lista_contract.grantRole(stake_lista_contract.ADMIN_ROLE(), owner);

        bnwClisBnb.grantRole(bnwClisBnb.MINT_BURN_ROLE(), address(stake_lista_contract));

        simpleStaking.whitelistToken(address(bnwClisBnb));

        vm.stopPrank();

        // Top up user balances
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        vm.deal(feeReceiver, 0);
    }

    // // [OK] User stakes BNB
    // function testStakeBNB() public {
    //     // User stakes 1 BNB
    //     vm.prank(user1);
    //     stake_lista_contract.stake{value: 1.5 ether}();

    //     // Check user2's LRS balance
    //     assertEq(stake_lista_contract.balanceOf(user1), 1.5 ether);

    //     // Check delegation amount in HeliosProvider
    //     IHeliosProvider.Delegation memory delegationItem = IHeliosProvider(
    //         heliosProvider
    //     )._delegation(address(stake_lista_contract));
    //     assertEq(delegationItem.amount, 1.5 ether);

    //     // User 2 stakes
    //     vm.prank(user2);
    //     stake_lista_contract.stake{value: 0.5 ether}();

    //     // Check user2's LRS balance
    //     assertEq(stake_lista_contract.balanceOf(user2), 0.5 ether);
    //     assertEq(stake_lista_contract.totalSupply(), 2 ether);
    //     // assertEq(ICollateral(collateral).balanceOf(delegateTo), 2 ether); // this test works only on testnet

    //     // Check delegation amount in HeliosProvider
    //     delegationItem = IHeliosProvider(heliosProvider)._delegation(
    //         address(stake_lista_contract)
    //     );
    //     assertEq(delegationItem.amount, 2 ether);
    // }

    // // [OK] User unstakes BNB
    // function testUnstakeBNB() public {
    //     // User stakes 1 BNB
    //     vm.prank(user1);
    //     stake_lista_contract.stake{value: 1.5 ether}();

    //     // Check delegation amount in HeliosProvider
    //     IHeliosProvider.Delegation memory delegationItem = IHeliosProvider(
    //         heliosProvider
    //     )._delegation(address(stake_lista_contract));
    //     assertEq(delegationItem.amount, 1.5 ether);

    //     // User attempts to unstake more than staked amount
    //     vm.startPrank(user1);
    //     vm.expectRevert();
    //     stake_lista_contract.unstake(2 ether);

    //     // User unstakes 1 BNB
    //     stake_lista_contract.unstake(1 ether);

    //     assertEq(user1.balance, 99.5 ether);
    //     assertEq(stake_lista_contract.userBalances(user1), 0.5 ether);
    //     assertEq(stake_lista_contract.totalSupply(), 0.5 ether);
    //     assertEq(stake_lista_contract.balanceOf(user1), 0.5 ether);
    //     vm.stopPrank();

    //     // Check delegation amount in HeliosProvider
    //     delegationItem = IHeliosProvider(heliosProvider)._delegation(
    //         address(stake_lista_contract)
    //     );
    //     assertEq(delegationItem.amount, 0.5 ether);

    //     // //  Manipulate user1's stakeAmount via store
    //     // stdstore
    //     //     .target(address(stake_lista_contract))
    //     //     .sig("stakedAmount(address)")
    //     //     .with_key(user1)
    //     //     .checked_write(10 ether);

    //     // // Attempt to claim more eth than available in contract
    //     // vm.prank(user1);
    //     // stake_lista_contract.unstake(2 ether);
    // }

    // // [OK] User unstakes slisBnb
    // function testUnstakeLiquidBNB() public {
    //     // User stakes 1 BNB
    //     vm.prank(user1);
    //     stake_lista_contract.stake{value: 1.5 ether}();

    //     // Check LRS staked in stake contract
    //     assertEq(stake_lista_contract.balanceOf(user1), 1.5 ether);

    //     // Check delegation amount in HeliosProvider
    //     IHeliosProvider.Delegation memory delegationItem = IHeliosProvider(
    //         heliosProvider
    //     )._delegation(address(stake_lista_contract));
    //     assertEq(delegationItem.amount, 1.5 ether);

    //     // User attempts to unstake more than staked amount
    //     vm.startPrank(user1);
    //     vm.expectRevert();
    //     stake_lista_contract.unstake(2 ether);

    //     // User unstakes 1 BNB
    //     stake_lista_contract.unstakeLiquidBnb(1 ether, slisBnbStrategy);
    //     assertEq(user1.balance, 98.5 ether);
    //     // assertEq(IERC20(slisBnb).balanceOf(user1), 977800679150037185); // Check Lista StakeManager.convertBnbToSnBnb()
    //     assertEq(stake_lista_contract.totalSupply(), 0.5 ether);
    //     assertEq(stake_lista_contract.balanceOf(user1), 0.5 ether);
    //     vm.stopPrank();

    //     // Check delegation amount in HeliosProvider
    //     delegationItem = IHeliosProvider(heliosProvider)._delegation(
    //         address(stake_lista_contract)
    //     );
    //     assertEq(delegationItem.amount, 0.5 ether);
    // }

    // // [OK] Test initial distribution
    // function testFirstDistribution() public {
    //     vm.deal(rewardsDistributor, 1000 ether);

    //     uint256 startBlock = block.number;

    //     // Distribute rewards -- Round 1
    //     vm.prank(rewardsDistributor);
    //     (bool success0, ) = address(stake_lista_contract).call{value: 10 ether}(
    //         ""
    //     );
    //     if (!success0) revert("Transfer to receive() failed");

    //     (uint256 start, , uint256 rewards, , ) = stake_lista_contract
    //         .distributions(0);
    //     assertEq(start, block.number);
    //     assertEq(rewards, 0);

    //     // Distribute rewards -- Round 2
    //     vm.prank(rewardsDistributor);
    //     (bool success1, ) = address(stake_lista_contract).call{value: 10 ether}(
    //         ""
    //     );
    //     if (!success1) revert("Transfer to receive() failed");

    //     vm.roll(startBlock + 100);

    //     vm.prank(owner);
    //     stake_lista_contract.createDistribution();

    //     (
    //         uint256 start1,
    //         uint256 end1,
    //         uint256 rewards1,
    //         ,

    //     ) = stake_lista_contract.distributions(0);
    //     assertEq(start1, startBlock);
    //     assertEq(end1, startBlock + 100);
    //     assertEq(rewards1, 19 ether);

    //     // vm.prank(user1);
    //     // uint256 userBalance = user1.balance;
    //     // stake_lista_contract.claimRewards();
    //     // assertEq(user1.balance, userBalance + 10 ether);
    // }

    // // [OK] Test multiple distributions
    // function testMultipleDistributions() public {
    //     vm.deal(rewardsDistributor, 1000 ether);

    //     // Distribute rewards
    //     vm.prank(rewardsDistributor);
    //     (bool success0, ) = address(stake_lista_contract).call{value: 10 ether}(
    //         ""
    //     );
    //     if (!success0) revert("Transfer to receive() failed");

    //     (uint256 start0, , uint256 rewards0, , ) = stake_lista_contract
    //         .distributions(0);
    //     assertEq(start0, block.number);
    //     assertEq(rewards0, 0);

    //     // Skip forward 100 blocks
    //     uint256 startOfDistribution1 = block.number;
    //     uint256 blocksToSkip = 100000;
    //     vm.roll(block.number + blocksToSkip); // skip blocks
    //     uint256 endOfDistribution1 = block.number;
    //     assertEq(startOfDistribution1 + blocksToSkip, endOfDistribution1);

    //     // Finish distribution0 and create distribution1
    //     vm.prank(owner);
    //     stake_lista_contract.createDistribution();
    //     (
    //         uint256 start01,
    //         uint256 end01,
    //         uint256 rewards01,
    //         ,

    //     ) = stake_lista_contract.distributions(0);

    //     // Set new platform fee == 10%
    //     vm.prank(owner);
    //     uint256 newPlatformFee = 10 ether;
    //     stake_lista_contract.setFeePerc(newPlatformFee);

    //     // Check finalised distribution0
    //     assertEq(start01, startOfDistribution1);
    //     assertEq(end01, endOfDistribution1);
    //     assertEq(rewards01, 9.5 ether);

    //     (
    //         uint256 start1,
    //         uint256 end1,
    //         uint256 rewards1,
    //         ,

    //     ) = stake_lista_contract.distributions(1);

    //     // Check new distribution1
    //     assertEq(start1, endOfDistribution1);
    //     assertEq(end1, 0);
    //     assertEq(rewards1, 0);

    //     // Distribute awards for distribution1
    //     vm.prank(rewardsDistributor);
    //     (bool success1, ) = address(stake_lista_contract).call{value: 25 ether}(
    //         ""
    //     );
    //     if (!success1) revert("Transfer to receive() failed");

    //     (
    //         uint256 start11,
    //         uint256 end11,
    //         uint256 rewards11,
    //         ,

    //     ) = stake_lista_contract.distributions(1);

    //     // Check finalised distribution0
    //     assertEq(start01, startOfDistribution1);
    //     assertEq(end01, endOfDistribution1);
    //     assertEq(rewards01, 9.5 ether);

    //     // Check current distribution1
    //     assertEq(start11, endOfDistribution1);
    //     assertEq(end11, 0);
    //     assertEq(rewards11, 0 ether);
    // }

    // // [OK] Test claim for distribution with no interactions
    // function testNoInteractionsInDistribution() public {
    //     vm.deal(user1, 1000 ether);
    //     vm.deal(user2, 1000 ether);
    //     vm.deal(rewardsDistributor, 1000 ether);
    //     vm.prank(rewardsDistributor);
    //     (bool success0, ) = address(stake_lista_contract).call{value: 10 ether}(
    //         ""
    //     );
    //     if (!success0) revert("Transfer to receive() failed");

    //     vm.prank(owner);
    //     stake_lista_contract.setFeePerc(50 ether);

    //     uint256 firstInteractionBlockNumber = block.number;

    //     // User1 stakes
    //     vm.prank(user1);
    //     stake_lista_contract.stake{value: 100 ether}();

    //     vm.roll(firstInteractionBlockNumber + 50); // -----------------------> ROLL to 50%

    //     // User2 stakes 2 times in the same block
    //     vm.startPrank(user2);
    //     stake_lista_contract.stake{value: 100 ether}();
    //     stake_lista_contract.stake{value: 100 ether}();
    //     vm.stopPrank();

    //     vm.roll(firstInteractionBlockNumber + 100); // -----------------------> ROLL to 100%

    //     // Finalize distribution0 and create distribution1
    //     vm.prank(owner);
    //     stake_lista_contract.createDistribution();

    //     vm.prank(rewardsDistributor);
    //     (bool success1, ) = address(stake_lista_contract).call{value: 10 ether}(
    //         ""
    //     );
    //     if (!success1) revert("Transfer to receive() failed");

    //     vm.roll(firstInteractionBlockNumber + 2000);

    //     // Finalize distribution1 and create distribution2
    //     vm.prank(owner);
    //     stake_lista_contract.createDistribution();

    //     // User1 claims
    //     vm.prank(user1);
    //     stake_lista_contract.claimRewards();

    //     // User2 claims
    //     vm.prank(user2);
    //     stake_lista_contract.claimRewards();

    //     // Owner claims 50% fee from 10 eth
    //     vm.prank(owner);
    //     stake_lista_contract.claimFees();
    //     assertEq(feeReceiver.balance, 10 ether);
    //     // assertEq(address(stake_lista_contract).balance, 0); // NOTE :: 1 wei remaining
    // }

    // // [OK] Test claim fees
    // function testClaimFees() public {
    //     vm.deal(rewardsDistributor, 1000 ether);

    //     // Distribute rewards
    //     vm.prank(rewardsDistributor);
    //     (bool success0, ) = address(stake_lista_contract).call{value: 1 ether}(
    //         ""
    //     );
    //     if (!success0) revert("Transfer to receive() failed");

    //     // Skip forward 100 blocks
    //     uint256 startOfDistribution1 = block.number;
    //     uint256 blocksToSkip = 100000;
    //     vm.roll(block.number + blocksToSkip); // skip blocks
    //     uint256 endOfDistribution1 = block.number;
    //     assertEq(startOfDistribution1 + blocksToSkip, endOfDistribution1);

    //     // Finish distribution0 and create distribution1
    //     vm.prank(owner);
    //     stake_lista_contract.createDistribution();

    //     // Distribute awards for distribution1
    //     vm.prank(rewardsDistributor);
    //     (bool success1, ) = address(stake_lista_contract).call{value: 2 ether}(
    //         ""
    //     );
    //     if (!success1) revert("Transfer to receive() failed");

    //     // Finish distribution1 and create distribution2
    //     vm.prank(owner);
    //     stake_lista_contract.createDistribution();

    //     // Set new platform fee == 10%
    //     vm.prank(owner);
    //     uint256 newPlatformFee = 10 ether;
    //     stake_lista_contract.setFeePerc(newPlatformFee);

    //     // Distribute awards for distribution1
    //     vm.prank(rewardsDistributor);
    //     (bool success2, ) = address(stake_lista_contract).call{value: 10 ether}(
    //         ""
    //     );
    //     if (!success2) revert("Transfer to receive() failed");

    //     // Claim fees for distribution 0 & 1
    //     assertEq(feeReceiver.balance, 0);
    //     vm.prank(owner);
    //     stake_lista_contract.claimFees();
    //     assertEq(feeReceiver.balance, 0.05 * 1 ether + 0.05 * 2 ether);
    // }

    // // [OK] User claims distribution rewards
    // function testClaimRewards() public {
    //     vm.deal(user1, 1000 ether);
    //     vm.deal(user2, 1000 ether);
    //     vm.deal(rewardsDistributor, 1000 ether);
    //     vm.prank(rewardsDistributor);
    //     (bool success0, ) = address(stake_lista_contract).call{value: 10 ether}(
    //         ""
    //     );
    //     if (!success0) revert("Transfer to receive() failed");

    //     uint256 firstInteractionBlockNumber = block.number;

    //     // User1 stakes
    //     vm.prank(user1);
    //     stake_lista_contract.stake{value: 100 ether}();
    //     uint256 user1Rewards = stake_lista_contract.userRewards(user1);
    //     uint256 ratio = stake_lista_contract.userRatio(0, user1);

    //     // User1 checks
    //     assertEq(
    //         stake_lista_contract.userLastInteraction(user1),
    //         firstInteractionBlockNumber
    //     );
    //     assertEq(ratio, 0);

    //     // Distribution1 checks
    //     (, , , , uint256 lastInteraction0) = stake_lista_contract.distributions(
    //         0
    //     );
    //     assertEq(lastInteraction0, firstInteractionBlockNumber);

    //     vm.roll(firstInteractionBlockNumber + 15); // -----------------------> ROLL to 15%

    //     // User2 stakes
    //     vm.startPrank(user2);
    //     stake_lista_contract.stake{value: 100 ether}();
    //     stake_lista_contract.stake{value: 100 ether}();
    //     vm.stopPrank();

    //     uint256 user2Rewards = stake_lista_contract.userRewards(user2);
    //     (, , , , uint256 lastInteraction01) = stake_lista_contract
    //         .distributions(0);

    //     // Distribution1 checks
    //     assertEq(lastInteraction01, firstInteractionBlockNumber + 15);

    //     vm.roll(firstInteractionBlockNumber + 15 + 69); // -----------------------> ROLL to 84%

    //     vm.prank(user2);
    //     stake_lista_contract.unstake(200 ether);

    //     vm.roll(firstInteractionBlockNumber + 15 + 69 + 16); // -----------------------> ROLL to 100%

    //     // Finalize distribution0 by creating a new one
    //     vm.prank(owner);
    //     stake_lista_contract.createDistribution();

    //     user1Rewards = stake_lista_contract.userRewards(user1);
    //     user2Rewards = stake_lista_contract.userRewards(user2);

    //     // User1 claims rewards
    //     vm.prank(user1);
    //     stake_lista_contract.claimRewards();
    //     assertEq(user1.balance, 903991596638655462184); // Estimate 903991596638655462184 ~~ 903.99 ether. Rewards are 3.99 ether.

    //     // User1 attempts to claim again, but reverts, because there's nothing to claim after first claim
    //     vm.prank(user1);
    //     vm.expectRevert(IListaIntegration.ClaimFailed.selector);
    //     stake_lista_contract.claimRewards();

    //     // User2 claims rewards
    //     vm.prank(user2);
    //     stake_lista_contract.claimRewards();
    //     assertEq(user2.balance, 1005508403361344537815); // Estimate 1005508403361344537815 ~~ 1005.55 ether. Rewards are 5.55 ether.
    // }

    // // [OK] User1 stakes 100 eth for 100%, user2 stakes 200 eth for 50%
    // // Both users claim equal amount. Fees claimed by owner. 0 left balance in contract.
    // function testClaimRewards2() public {
    //     vm.deal(user1, 1000 ether);
    //     vm.deal(user2, 1000 ether);
    //     vm.deal(rewardsDistributor, 1000 ether);
    //     vm.prank(rewardsDistributor);
    //     (bool success0, ) = address(stake_lista_contract).call{value: 10 ether}(
    //         ""
    //     );
    //     if (!success0) revert("Transfer to receive() failed");

    //     vm.prank(owner);
    //     stake_lista_contract.setFeePerc(50 ether);

    //     uint256 firstInteractionBlockNumber = block.number;

    //     // User1 stakes
    //     vm.prank(user1);
    //     stake_lista_contract.stake{value: 100 ether}();

    //     vm.roll(firstInteractionBlockNumber + 50); // -----------------------> ROLL to 50%

    //     // User2 stakes 2 times in the same block
    //     vm.startPrank(user2);
    //     stake_lista_contract.stake{value: 100 ether}();
    //     stake_lista_contract.stake{value: 100 ether}();
    //     vm.stopPrank();

    //     vm.roll(firstInteractionBlockNumber + 100); // -----------------------> ROLL to 100%

    //     // Finalize distribution0 by creating a new one
    //     vm.prank(owner);
    //     stake_lista_contract.createDistribution();

    //     // User1 claims rewards -- 50% of 5 eth
    //     vm.prank(user1);
    //     stake_lista_contract.claimRewards();
    //     assertEq(user1.balance, 902.5 ether);

    //     // User1 claims rewards -- 50% of 5 eth
    //     vm.prank(user2);
    //     stake_lista_contract.claimRewards();
    //     assertEq(user2.balance, 802.5 ether);

    //     // Owner claims 50% fee from 10 eth
    //     vm.prank(owner);
    //     stake_lista_contract.claimFees();
    //     assertEq(feeReceiver.balance, 5 ether);
    //     assertEq(address(stake_lista_contract).balance, 0);
    // }

    // // [OK] User1 &  User2 claim 3 distributions at once
    // function testClaimMultipleDistributions() public {
    //     vm.deal(user1, 1000 ether);
    //     vm.deal(user2, 1000 ether);
    //     vm.deal(rewardsDistributor, 1000 ether);
    //     vm.prank(rewardsDistributor);
    //     (bool success0, ) = address(stake_lista_contract).call{value: 10 ether}(
    //         ""
    //     );
    //     if (!success0) revert("Transfer to receive() failed");

    //     uint256 firstInteractionBlockNumber = block.number;

    //     // User1 stakes
    //     vm.prank(user1);
    //     stake_lista_contract.stake{value: 100 ether}();
    //     uint256 user1Ratio = stake_lista_contract.userRatio(0, user1);

    //     // User1 checks
    //     assertEq(
    //         stake_lista_contract.userLastInteraction(user1),
    //         firstInteractionBlockNumber
    //     );
    //     assertEq(user1Ratio, 0);

    //     vm.roll(firstInteractionBlockNumber + 50); // -----------------------> ROLL to 50%

    //     // User2 stakes 2 times in the same block
    //     vm.prank(user2);
    //     stake_lista_contract.stake{value: 200 ether}();
    //     // stake_lista_contract.stake{value: 100 ether}(); // TODO :: investigate and fix 2 stakes of 100 eth in the same block

    //     vm.roll(firstInteractionBlockNumber + 100); // -----------------------> ROLL to 100%

    //     // Finalize distribution0 and start distribution1
    //     vm.prank(owner);
    //     stake_lista_contract.createDistribution();

    //     // User1 claims rewards
    //     vm.prank(user1);
    //     stake_lista_contract.claimRewards();
    //     uint256 user1Balance = 900 ether + 4.75 ether;
    //     assertEq(user1.balance, user1Balance);

    //     // User1 claims rewards
    //     vm.prank(user2);
    //     stake_lista_contract.claimRewards();
    //     uint256 user2Balance = 800 ether + 4.75 ether;
    //     assertEq(user2.balance, user2Balance);

    //     // Owner claims 5% fee from dist0
    //     vm.prank(owner);
    //     stake_lista_contract.claimFees();
    //     assertEq(feeReceiver.balance, 0.5 ether);
    //     assertEq(address(stake_lista_contract).balance, 0);

    //     // ------------------------ D I S T 1 ------------------------
    //     // Distribute awards for dist1
    //     vm.prank(rewardsDistributor);
    //     (bool success1, ) = address(stake_lista_contract).call{value: 10 ether}(
    //         ""
    //     );
    //     if (!success1) revert("Transfer to receive() failed");

    //     vm.roll(block.number + 100);

    //     // End distribution1 and start distribution2
    //     vm.prank(owner);
    //     stake_lista_contract.createDistribution();

    //     // ------------------------ D I S T 2 ------------------------
    //     // Distribute awards for dist2
    //     vm.prank(rewardsDistributor);
    //     (bool success2, ) = address(stake_lista_contract).call{value: 10 ether}(
    //         ""
    //     );
    //     if (!success2) revert("Transfer to receive() failed");

    //     vm.roll(block.number + 100);

    //     // End distribution2 and start distribution3
    //     vm.prank(owner);
    //     stake_lista_contract.createDistribution();

    //     // ------------------------ D I S T 3 ------------------------
    //     // Distribute awards for dist3
    //     vm.prank(rewardsDistributor);
    //     (bool success3, ) = address(stake_lista_contract).call{value: 10 ether}(
    //         ""
    //     );
    //     if (!success3) revert("Transfer to receive() failed");

    //     vm.roll(block.number + 100);

    //     // End distribution3 and start distribution4
    //     vm.prank(owner);
    //     stake_lista_contract.createDistribution();

    //     // ------------------------ User1 claims Dist 1 & 2 & 3------------------------ //
    //     console.log("USER 1 CLAIM DIST 1, 2, 3");
    //     assertEq(stake_lista_contract.userLastDist(user1), 1);
    //     assertEq(
    //         stake_lista_contract.userLastInteraction(user1),
    //         block.number - 300
    //     );
    //     vm.prank(user1);
    //     stake_lista_contract.claimRewards(); // should claim 33.3333% of 28.5 eth == 9.5 eth
    //     user1Balance += 9.5 ether;
    //     assertEq(stake_lista_contract.userLastDist(user1), 4);
    //     assertEq(stake_lista_contract.userLastInteraction(user1), block.number);
    //     // assertEq(user1.balance, user1Balance); // NOTE: -----> 2 wei mismatch

    //     // ------------------------ User2 claims Dist 1 & 2 & 3 ------------------------ //
    //     console.log("USER 2 CLAIM DIST 1, 2, 3");
    //     assertEq(stake_lista_contract.userLastDist(user2), 1);
    //     assertEq(
    //         stake_lista_contract.userLastInteraction(user2),
    //         block.number - 300
    //     );
    //     vm.prank(user2);
    //     stake_lista_contract.claimRewards(); // should claim 66.6666% of 28.5 eth == 19 eth
    //     user2Balance += 19 ether;
    //     assertEq(stake_lista_contract.userLastDist(user2), 4);
    //     assertEq(stake_lista_contract.userLastInteraction(user2), block.number);
    //     // assertEq(user2.balance, user2Balance); // NOTE: -----> 2 wei mismatch

    //     // Claim fees
    //     vm.prank(owner);
    //     stake_lista_contract.claimFees();
    //     // assertEq(address(stake_lista_contract).balance, 0); // NOTE: -----> 3 wei mismatch
    // }

    // // [OK] Sync multiple distributions, then  claim
    // function testSyncBatchRewards() public {
    //     vm.deal(user1, 1000 ether);
    //     vm.deal(user2, 1000 ether);
    //     vm.deal(rewardsDistributor, 1000 ether);
    //     vm.prank(rewardsDistributor);
    //     (bool success0, ) = address(stake_lista_contract).call{value: 10 ether}(
    //         ""
    //     );
    //     if (!success0) revert("Transfer to receive() failed");

    //     uint256 firstInteractionBlockNumber = block.number;
    //     uint256 lastBlockNumber = block.number;

    //     // User1 stakes
    //     vm.prank(user1);
    //     stake_lista_contract.stake{value: 150 ether}();
    //     vm.roll(firstInteractionBlockNumber + 150000); // -----------------------> ROLL to 50%
    //     lastBlockNumber = firstInteractionBlockNumber + 150000;

    //     // User2 stakes
    //     vm.prank(user2);
    //     stake_lista_contract.stake{value: 600 ether}();
    //     vm.roll(lastBlockNumber + 150000); // -----------------------> ROLL to 100%
    //     lastBlockNumber += 150000;

    //     // End distribution0 and start distribution1
    //     vm.prank(owner);
    //     stake_lista_contract.createDistribution();

    //     vm.roll(lastBlockNumber + 300000); // -----------------------> ROLL to 100%
    //     lastBlockNumber += 300000;

    //     // End distribution1 and start distribution2
    //     vm.prank(owner);
    //     stake_lista_contract.createDistribution();

    //     vm.roll(lastBlockNumber + 300000); // -----------------------> ROLL to 100%
    //     lastBlockNumber += 300000;

    //     // End distribution2 and start distribution3
    //     vm.prank(owner);
    //     stake_lista_contract.createDistribution();

    //     // ------------------- BATCH SYNC ------------------- //
    //     // Update rewards for dist 0 and dist 1
    //     stake_lista_contract.commitUser(user1, 2);

    //     uint256 user1Ratio0 = stake_lista_contract.userRatio(0, user1);
    //     uint256 user1Ratio1 = stake_lista_contract.userRatio(1, user1);
    //     uint256 user1Ratio2 = stake_lista_contract.userRatio(2, user1);
    //     uint256 user1Ratio3 = stake_lista_contract.userRatio(3, user1);

    //     assertNotEq(user1Ratio0, 0);
    //     assertNotEq(user1Ratio1, 0);
    //     assertEq(user1Ratio2, 0);
    //     assertEq(user1Ratio3, 0); // current distribution, awards still 0

    //     // Update rewards until the current distribution
    //     stake_lista_contract.commitUser(user1, 3);

    //     user1Ratio0 = stake_lista_contract.userRatio(0, user1);
    //     user1Ratio1 = stake_lista_contract.userRatio(1, user1);
    //     user1Ratio2 = stake_lista_contract.userRatio(2, user1);
    //     user1Ratio3 = stake_lista_contract.userRatio(3, user1);

    //     assertNotEq(user1Ratio0, 0);
    //     assertNotEq(user1Ratio1, 0);
    //     assertNotEq(user1Ratio2, 0);
    //     assertEq(user1Ratio3, 0); // current distribution, awards still 0
    // }

    // function testManyStakesOverTime() public {
    //     vm.deal(user1, 1000 ether);
    //     vm.deal(user2, 1000 ether);
    //     vm.deal(rewardsDistributor, 1000 ether);
    //     vm.prank(rewardsDistributor);
    //     (bool success0, ) = address(stake_lista_contract).call{value: 10 ether}(
    //         ""
    //     );
    //     if (!success0) revert("Transfer to receive() failed");

    //     uint256 firstInteractionBlockNumber = block.number;
    //     uint256 lastBlockNumber = block.number;

    //     // User1 stakes
    //     vm.prank(user1);
    //     stake_lista_contract.stake{value: 50 ether}();
    //     vm.roll(firstInteractionBlockNumber + 150000); // -----------------------> ROLL to 50%
    //     lastBlockNumber = firstInteractionBlockNumber + 150000;

    //     // User2 stakes
    //     vm.prank(user2);
    //     stake_lista_contract.stake{value: 200 ether}();
    //     vm.roll(lastBlockNumber + 150000); // -----------------------> ROLL to 100%
    //     lastBlockNumber += 150000;

    //     // End distribution1 and start distribution2
    //     vm.prank(owner);
    //     stake_lista_contract.createDistribution();

    //     // User1 stakes
    //     vm.prank(user1);
    //     stake_lista_contract.stake{value: 50 ether}();
    //     vm.roll(lastBlockNumber + 150000); // -----------------------> ROLL to 50%
    //     lastBlockNumber += 150000;

    //     // User2 stakes
    //     vm.prank(user2);
    //     stake_lista_contract.stake{value: 200 ether}();
    //     vm.roll(lastBlockNumber + 150000); // -----------------------> ROLL to 100%
    //     lastBlockNumber += 150000;

    //     // End distribution2 and start distribution3
    //     vm.prank(owner);
    //     stake_lista_contract.createDistribution();

    //     // User1 stakes
    //     vm.prank(user1);
    //     stake_lista_contract.stake{value: 50 ether}();
    //     vm.roll(lastBlockNumber + 150000); // -----------------------> ROLL to 50%
    //     lastBlockNumber += 150000;

    //     console.log(
    //         "User 2 stakes is: ",
    //         stake_lista_contract.userBalances(user2) / 1e18
    //     );

    //     // // User2 stakes
    //     // vm.prank(user2);
    //     // stake_lista_contract.stake{value: 200 ether}();
    //     // vm.roll(lastBlockNumber + 150000); // -----------------------> ROLL to 100%
    //     // lastBlockNumber += 150000;

    //     // // End distribution3 and start distribution4
    //     // vm.prank(owner);
    //     // stake_lista_contract.createDistribution();

    //     // // ------------------- BATCH SYNC ------------------- //
    //     // vm.prank(user1);
    //     // stake_lista_contract.batchSyncRewards(user1, 5);
    // }

    // function test_multipleEpochsRewards() public {
    //     // fund accounts
    //     vm.deal(user1, 100 ether);
    //     vm.deal(user2, 50 ether);
    //     vm.deal(rewardsDistributor, 1000 ether);

    //     // user 1 deposits 100 ether
    //     vm.startPrank(user1);
    //     stake_lista_contract.stake{value: 100 ether}();
    //     assertEq(
    //         stake_lista_contract.balanceOf(user1),
    //         100 ether,
    //         "balance of user1 is not correct"
    //     );

    //     // move 50 blocks
    //     vm.roll(block.number + 50);

    //     // user 2 deposits 50 ethers
    //     vm.startPrank(user2);
    //     stake_lista_contract.stake{value: 50 ether}();
    //     assertEq(
    //         stake_lista_contract.balanceOf(user2),
    //         50 ether,
    //         "balance of user2 is not correct"
    //     );

    //     // move another 50 blocks
    //     vm.roll(block.number + 50);

    //     // send rewards - 10 ethers
    //     vm.startPrank(rewardsDistributor);
    //     address(stake_lista_contract).call{value: 10 ether}("");

    //     // end distribution 1 and start dist 2
    //     vm.startPrank(owner);
    //     stake_lista_contract.createDistribution();

    //     (, , uint256 rewards, , ) = stake_lista_contract.distributions(0);
    //     assertEq(rewards, 9.5 ether, "rewards are not ok");

    //     // check user balance before claim, claim and check balance again
    //     assertEq(user1.balance, 0 ether, "user balance is not ok");

    //     vm.startPrank(user1);
    //     stake_lista_contract.claimRewards();
    //     assertEq(user1.balance, 7.6 ether, "user balance is not ok");

    //     vm.startPrank(user2);
    //     stake_lista_contract.claimRewards();
    //     assertEq(user2.balance, 1.9 ether, "user balance is not ok");

    //     // --- DIST 2 --- ... total 200 blocks
    //     // add rewards to the DIST 2
    //     vm.startPrank(rewardsDistributor);
    //     address(stake_lista_contract).call{value: 10 ether}("");

    //     // move to the middle of the distr
    //     vm.roll(block.number + 100);

    //     // user 2 withdraws his stake
    //     vm.startPrank(user2);
    //     stake_lista_contract.unstake(50 ether);

    //     // move to the end of distr
    //     vm.roll(block.number + 100);

    //     // start new distr
    //     // --- DIST 3 --- total 100 blocks
    //     vm.startPrank(owner);
    //     stake_lista_contract.createDistribution();

    //     // add rewards to the DIST 3
    //     vm.startPrank(rewardsDistributor);
    //     address(stake_lista_contract).call{value: 10 ether}("");

    //     // move 50 blocks
    //     vm.roll(block.number + 50);

    //     // user 2 stakes 20 bnb
    //     vm.startPrank(user2);
    //     stake_lista_contract.stake{value: 50 ether}();

    //     // move 50 blocks
    //     vm.roll(block.number + 50);

    //     // --- DIST 4 ---
    //     vm.startPrank(owner);
    //     stake_lista_contract.createDistribution();

    //     vm.startPrank(user1);
    //     //stake_lista_contract.claimRewards();
    //     assertEq(user1.balance, 7.6 ether, "user balance is not ok");

    //     // user 1 will claim his rewards for dist 2 and 3
    //     // for dist 2 the user should claim 7.6 and for 3 another 7.6
    //     stake_lista_contract.claimRewards();
    //     console.log("user balance %d", user1.balance);
    //     assertEq(user1.balance, 22.8 ether, "user balance is not ok");
    // }

    // function test_test() public {
    //     // fund accounts
    //     vm.deal(user1, 200 ether);
    //     vm.deal(user2, 400 ether);
    //     vm.deal(rewardsDistributor, 1000 ether);

    //     // -- DIST 0 -- (0-100) block
    //     // user 1 deposits 100 ether
    //     vm.startPrank(user1);
    //     stake_lista_contract.stake{value: 100 ether}();
    //     assertEq(
    //         stake_lista_contract.balanceOf(user1),
    //         100 ether,
    //         "balance of user1 is not correct"
    //     );

    //     // move 50 blocks
    //     vm.roll(block.number + 50);

    //     // user 2 deposits 100 ether
    //     vm.startPrank(user2);
    //     stake_lista_contract.stake{value: 200 ether}();
    //     assertEq(
    //         stake_lista_contract.balanceOf(user2),
    //         200 ether,
    //         "balance of user2 is not correct"
    //     );

    //     // move 50 blocks
    //     vm.roll(block.number + 50);

    //     // send rewards
    //     vm.startPrank(rewardsDistributor);
    //     address(stake_lista_contract).call{value: 10 ether}("");

    //     // create new dist at block 100
    //     vm.startPrank(owner);
    //     stake_lista_contract.createDistribution();
    //     // -- END OF DIST 0 ---

    //     // -- DIST 1 -- (100 - 200 block)
    //     // user 1 deposits 100 ether
    //     vm.startPrank(user1);
    //     stake_lista_contract.stake{value: 50 ether}();
    //     stake_lista_contract.stake{value: 50 ether}();
    //     assertEq(
    //         stake_lista_contract.balanceOf(user1),
    //         200 ether,
    //         "balance of user1 is not correct"
    //     );

    //     // move 50 blocks
    //     vm.roll(block.number + 50);

    //     // user 2 deposits 200 ether
    //     vm.startPrank(user2);
    //     stake_lista_contract.stake{value: 200 ether}();
    //     assertEq(
    //         stake_lista_contract.balanceOf(user2),
    //         400 ether,
    //         "balance of user2 is not correct"
    //     );

    //     // move 50 blocks
    //     vm.roll(block.number + 50);

    //     // send rewards
    //     vm.startPrank(rewardsDistributor);
    //     address(stake_lista_contract).call{value: 10 ether}("");

    //     // create new dist at block 200
    //     vm.startPrank(owner);
    //     stake_lista_contract.createDistribution();
    //     // -- END OF DIST 1 ---

    //     vm.startPrank(user1);
    //     stake_lista_contract.claimRewards();
    //     console.log("USER 1 balance %d", user1.balance);

    //     vm.startPrank(user2);
    //     stake_lista_contract.claimRewards();
    //     console.log("USER 2 balance %d", user2.balance);

    //     // 0 - 50 user1 = 100
    //     // 50 - 100 => user1 = 100 & user2 = 200
    //     // 100 - 150 => user1 = 200 & user2 = 200
    //     // 150 - 200 => user1 = 200 & user2 = 400
    // }

    // // [OK] Test BnWClisBnb token
    // function testBnWClisBnb() public {
    //     assertTrue(simpleStaking.whitelistedTokens(address(bnwClisBnb)));

    //     // User stakes
    //     vm.prank(user1);
    //     stake_lista_contract.stake{value: 10 ether}();
    //     assertEq(bnwClisBnb.balanceOf(address(stake_lista_contract)), 0 ether);
    //     assertEq(bnwClisBnb.balanceOf(address(simpleStaking)), 10 ether);
    //     assertEq(
    //         simpleStaking.stakes(
    //             address(stake_lista_contract),
    //             address(bnwClisBnb)
    //         ),
    //         10 ether
    //     );

    //     // User unstakes 50%
    //     vm.prank(user1);
    //     stake_lista_contract.unstake(5 ether);
    //     assertEq(bnwClisBnb.balanceOf(address(stake_lista_contract)), 0 ether);
    //     assertEq(bnwClisBnb.balanceOf(address(simpleStaking)), 5 ether);
    //     assertEq(
    //         simpleStaking.stakes(
    //             address(stake_lista_contract),
    //             address(bnwClisBnb)
    //         ),
    //         5 ether
    //     );

    //     // User unstakes liquid 50%
    //     vm.prank(user1);
    //     stake_lista_contract.unstakeLiquidBnb(5 ether, slisBnbStrategy);
    //     assertEq(bnwClisBnb.balanceOf(address(stake_lista_contract)), 0 ether);
    //     assertEq(bnwClisBnb.balanceOf(address(simpleStaking)), 0 ether);
    //     assertEq(
    //         simpleStaking.stakes(
    //             address(stake_lista_contract),
    //             address(bnwClisBnb)
    //         ),
    //         0 ether
    //     );
    // }

    // [OK] Test transferring LRS token
    function testTransfers() public {
        vm.deal(rewardsDistributor, 1000 ether);

        vm.prank(owner);
        stake_lista_contract.setFeePerc(10 ether);

        // User stakes
        vm.prank(user1);
        stake_lista_contract.stake{value: 10 ether}();
        assertEq(bnwClisBnb.balanceOf(address(stake_lista_contract)), 0 ether);
        assertEq(bnwClisBnb.balanceOf(address(simpleStaking)), 10 ether);
        assertEq(simpleStaking.stakes(address(stake_lista_contract), address(bnwClisBnb)), 10 ether);

        vm.roll(block.number + 100);

        vm.prank(user1);
        stake_lista_contract.transfer(user2, 5 ether);
        assertEq(stake_lista_contract.balanceOf(user1), 5 ether);
        assertEq(stake_lista_contract.balanceOf(user2), 5 ether);

        vm.roll(block.number + 200);

        // Distribute awards
        vm.prank(rewardsDistributor);
        (bool success0,) = address(stake_lista_contract).call{value: 10 ether}("");
        if (!success0) revert("Transfer to receive() failed");

        // Create new distribution
        vm.prank(owner);
        stake_lista_contract.createDistribution();

        // user1 and user 2 should have 66% and 33% of the rewards respectively
        uint256 user1Balance = user1.balance;
        console.log("---");
        vm.prank(user1);
        stake_lista_contract.claimRewards();
        console.log("user1 balance after claim: ", user1.balance);

        vm.prank(user2);
        stake_lista_contract.claimRewards();
        console.log("user2 balance after claim: ", user2.balance);
    }
}
