// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Staker} from "staker/Staker.sol";
import {ObolStaker, IERC20} from "src/ObolStaker.sol";
import {Staker} from "staker/Staker.sol";
import {MainnetObolDeploy} from "script/MainnetObolDeploy.s.sol";
import {PercentAssertions} from "staker-test/helpers/PercentAssertions.sol";
import {IEarningPowerCalculator} from "staker/interfaces/IEarningPowerCalculator.sol";
import {RebasingStakedObol} from "src/RebasingStakedObol.sol";
import {IntegrationTest} from "test/IntegrationTest.sol";
import {GovLst} from "stGOV/GovLst.sol";

abstract contract ObolStakerIntegrationTestBase is IntegrationTest, PercentAssertions {
  function getBlockHeightForFork() internal view virtual returns (uint256);

  function setUp() public virtual {
    // Fork mainnet to run the tests
    // vm.createSelectFork(vm.rpcUrl(MAINNET_RPC_URL), getBlockHeightForFork());
    vm.createSelectFork(vm.rpcUrl("mainnet_rpc_url"), getBlockHeightForFork());
  }

  function testForkFuzz_CorrectlyStakeAndEarnRewardsAfterDuration(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _percentDuration
  ) public {
    _assumeSafeAddress(_depositor);
    _assumeSafeAddress(_delegatee);

    _amount = _dealStakingToken(_depositor, _amount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _percentDuration = bound(_percentDuration, 0, 100);

    vm.startPrank(_depositor);
    IERC20(address(obolStaker.STAKE_TOKEN())).approve(address(obolStaker), _amount);
    ObolStaker.DepositIdentifier _depositId = obolStaker.stake(_amount, _delegatee);
    uint256 _totalEarningPowerAfterStake = obolStaker.totalEarningPower();
    vm.stopPrank();
    _mintTransferAndNotifyReward(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    // Calculate expected rewards based on % of duration and compare with actual unclaimed rewards
    uint256 expectedRewards = (_rewardAmount * _percentDuration) / 100;
    uint256 unclaimedRewards = obolStaker.unclaimedReward(_depositId);

    // scale the expected rewards based on the percentage of total earning power
    //  (which includes StakeToBurn from the LST deploy)
    expectedRewards = ((expectedRewards * (_amount * 100) / _totalEarningPowerAfterStake) / 100) + 1;

    assertLteWithinOnePercent(unclaimedRewards, expectedRewards);
  }

  function testForkFuzz_CorrectlyStakeMoreAndEarnRewardsAfterDuration(
    address _depositor,
    uint96 _initialAmount,
    uint96 _additionalAmount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _percentDuration
  ) public {
    vm.skip(true); //TODO: fix this test
    _assumeSafeAddress(_depositor);
    _assumeSafeAddress(_delegatee);

    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _percentDuration = bound(_percentDuration, 0, 100);

    // Only deal the initial amount first
    _initialAmount = _dealStakingToken(_depositor, _initialAmount);

    // Approve and stake initial amount
    vm.startPrank(_depositor);
    IERC20(address(obolStaker.STAKE_TOKEN())).approve(address(obolStaker), _initialAmount);
    ObolStaker.DepositIdentifier _depositId = obolStaker.stake(_initialAmount, _delegatee);
    vm.stopPrank();

    _mintTransferAndNotifyReward(_rewardAmount);
    _percentDuration = bound(_percentDuration, 0, 100);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    // Deal the additional tokens just before staking more
    _additionalAmount = uint96(bound(_additionalAmount, 0, 1e18 - _initialAmount));
    deal(address(obolStaker.STAKE_TOKEN()), _depositor, _additionalAmount);

    // Approve and stake additional amount
    vm.startPrank(_depositor);
    IERC20(address(obolStaker.STAKE_TOKEN())).approve(address(obolStaker), _additionalAmount);
    obolStaker.stakeMore(_depositId, _additionalAmount);
    vm.stopPrank();

    // get the total earning power after all the staking
    uint256 _totalEarningPowerAfterStakes = obolStaker.totalEarningPower();

    // Jump ahead to complete the reward duration
    _jumpAheadByPercentOfRewardDuration(100 - _percentDuration);

    // Calculate expected rewards:
    // 1. Rewards earned with initial amount during first period
    uint256 expectedRewardsPeriod1 =
      (_rewardAmount * _percentDuration * _initialAmount) / (100 * (_initialAmount));
    // 2. Rewards earned with combined amount during second period
    uint256 expectedRewardsPeriod2 = (_rewardAmount * (100 - _percentDuration)) / 100;
    uint256 totalExpectedRewards = expectedRewardsPeriod1 + expectedRewardsPeriod2 + 1;

    // scale the expected rewards based on the percentage of total earning power
    //  (which includes StakeToBurn from the LST deploy)
    totalExpectedRewards = (
      (
        totalExpectedRewards * ((_initialAmount + _additionalAmount) * 100)
          / _totalEarningPowerAfterStakes
      ) / 100
    ) + 1;

    // Assert that the unclaimed rewards are within one percent of the expected amount
    assertLteWithinOnePercent(obolStaker.unclaimedReward(_depositId), totalExpectedRewards);
  }

  function testForkFuzz_CorrectlyUnstakeAfterDuration(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _withdrawAmount,
    uint256 _percentDuration
  ) public {
    _assumeSafeAddress(_depositor);
    _assumeSafeAddress(_delegatee);

    _amount = _dealStakingToken(_depositor, _amount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _withdrawAmount = bound(_withdrawAmount, 0.1e18, _amount);
    _percentDuration = bound(_percentDuration, 0, 100);

    vm.startPrank(_depositor);
    IERC20(address(obolStaker.STAKE_TOKEN())).approve(address(obolStaker), _amount);
    ObolStaker.DepositIdentifier _depositId = obolStaker.stake(_amount, _delegatee);
    vm.stopPrank();

    _mintTransferAndNotifyReward(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 oldBalance = IERC20(address(obolStaker.STAKE_TOKEN())).balanceOf(_depositor);

    vm.prank(_depositor);
    obolStaker.withdraw(_depositId, _withdrawAmount);

    uint256 newBalance = IERC20(address(obolStaker.STAKE_TOKEN())).balanceOf(_depositor);
    assertEq(newBalance - oldBalance, _withdrawAmount);
  }

  function testForkFuzz_CorrectlyStakeAndClaimRewardsAfterDuration(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _percentDuration
  ) public {
    _assumeSafeAddress(_depositor);
    _assumeSafeAddress(_delegatee);

    _amount = _dealStakingToken(_depositor, _amount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _percentDuration = bound(_percentDuration, 0, 100);

    vm.startPrank(_depositor);
    IERC20(address(obolStaker.STAKE_TOKEN())).approve(address(obolStaker), _amount);
    ObolStaker.DepositIdentifier _depositId = obolStaker.stake(_amount, _delegatee);
    uint256 _totalEarningPowerAfterStake = obolStaker.totalEarningPower();
    vm.stopPrank();

    _mintTransferAndNotifyReward(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 oldBalance = IERC20(address(obolStaker.REWARD_TOKEN())).balanceOf(_depositor);

    vm.prank(_depositor);
    obolStaker.claimReward(_depositId);

    uint256 newBalance = IERC20(address(obolStaker.REWARD_TOKEN())).balanceOf(_depositor);

    // Calculate expected rewards based on percentage of duration
    uint256 expectedRewards = (_rewardAmount * _percentDuration) / 100;

    // scale the expected rewards based on the percentage of total earning power
    //  (which includes StakeToBurn from the LST deploy)
    expectedRewards = ((expectedRewards * (_amount * 100) / _totalEarningPowerAfterStake) / 100) + 1;

    assertLteWithinOnePercent(newBalance - oldBalance, expectedRewards);
    assertEq(obolStaker.unclaimedReward(_depositId), 0);
  }

  function testForkFuzz_CorrectlyUnstakeAndClaimRewardsAfterDuration(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _withdrawAmount,
    uint256 _percentDuration
  ) public {
    _assumeSafeAddress(_depositor);
    _assumeSafeAddress(_delegatee);

    _amount = _dealStakingToken(_depositor, _amount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _withdrawAmount = bound(_withdrawAmount, 0.1e18, _amount);
    _percentDuration = bound(_percentDuration, 0, 100);

    vm.startPrank(_depositor);
    IERC20(address(obolStaker.STAKE_TOKEN())).approve(address(obolStaker), _amount);
    ObolStaker.DepositIdentifier _depositId = obolStaker.stake(_amount, _delegatee);
    uint256 _totalEarningPowerAfterStake = obolStaker.totalEarningPower();
    vm.stopPrank();

    _mintTransferAndNotifyReward(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 oldStakeBalance = IERC20(address(obolStaker.STAKE_TOKEN())).balanceOf(
      address(obolStaker.surrogates(_delegatee))
    );
    uint256 oldRewardBalance = IERC20(address(obolStaker.REWARD_TOKEN())).balanceOf(_depositor);

    vm.startPrank(_depositor);
    obolStaker.withdraw(_depositId, _withdrawAmount);
    obolStaker.claimReward(_depositId);
    vm.stopPrank();

    uint256 newStakeBalance = IERC20(address(obolStaker.STAKE_TOKEN())).balanceOf(
      address(obolStaker.surrogates(_delegatee))
    );
    assertEq(oldStakeBalance - newStakeBalance, _withdrawAmount);

    // Calculate expected rewards based on percentage of duration
    uint256 expectedRewards = (_rewardAmount * _percentDuration) / 100;

    // scale the expected rewards based on the percentage of total earning power
    //  (which includes StakeToBurn from the LST deploy)
    if (expectedRewards > 0) {
      expectedRewards =
        ((expectedRewards * (_amount * 100) / _totalEarningPowerAfterStake) / 100) + 1;
    }

    // Because STAKE_TOKEN and REWARD_TOKEN are the same (OBOL_TOKEN), the STAKE_TOKEN withdrawn to
    // the depositor address, the balance of the REWARD_TOKEN in the depositor address is also
    // increased.
    uint256 newRewardBalance = IERC20(address(obolStaker.REWARD_TOKEN())).balanceOf(_depositor);
    assertLteWithinOnePercent(
      newRewardBalance - oldRewardBalance - _withdrawAmount, expectedRewards
    );
    assertEq(obolStaker.unclaimedReward(_depositId), 0);
  }
}

contract ObolStakerDeploymentTest is ObolStakerIntegrationTestBase {
  // Obol Multisig
  address OBOL_STAKER_ADMIN = 0x42D201CC4d9C1e31c032397F54caCE2f48C1FA72;
  // Tally Multisig
  address LST_OWNER = 0x7E90E03654732ABedF89Faf87f05BcD03ACEeFdC;

  uint256 constant MAX_BUMP_TIP = 10e18;

  MainnetObolDeploy deployScript;

  function getBlockHeightForFork() internal pure override returns (uint256) {
    return 22_289_468; // Block height for mainnet before Obol Staker production deployment
  }

  function setUp() public virtual override {
    super.setUp();
    uint256 _deployerPrivateKey = vm.envOr(
      "DEPLOYER_PRIVATE_KEY",
      uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
    );
    deployer = vm.rememberKey(_deployerPrivateKey);

    // Fund the deployer with some OBOL
    deal(OBOL_TOKEN_ADDRESS, deployer, DEPLOYER_DEAL_AMOUNT);

    // deploy via script
    deployScript = new MainnetObolDeploy();
    deployScript.setUp();
    (obolStaker, calculator, obolLst, autoDelegate) = deployScript.run();
  }

  function test_StakerDeployment() public view {
    MainnetObolDeploy.ObolStakerParams memory _stakerConfig = deployScript._getStakerConfig();

    assertEq(address(obolStaker.admin()), OBOL_STAKER_ADMIN);
    assertEq(address(obolStaker.REWARD_TOKEN()), address(_stakerConfig.rewardsToken));
    assertEq(address(obolStaker.STAKE_TOKEN()), address(_stakerConfig.stakeToken));
    assertEq(obolStaker.REWARD_DURATION(), REWARD_DURATION);
    assertEq(obolStaker.SCALE_FACTOR(), SCALE_FACTOR);
    assertEq(address(obolStaker.earningPowerCalculator()), address(calculator));
    assertEq(obolStaker.maxBumpTip(), MAX_BUMP_TIP);
  }

  function test_LstDeployment() public view {
    MainnetObolDeploy.ObolStakerParams memory _stakerConfig = deployScript._getStakerConfig();
    GovLst.ConstructorParams memory _lstConfig = deployScript._getLstConfig(autoDelegate);
    assertEq(address(obolLst.STAKER()), address(obolStaker));
    assertEq(address(obolLst.STAKE_TOKEN()), address(_stakerConfig.stakeToken));
    assertEq(address(obolLst.REWARD_TOKEN()), address(_stakerConfig.rewardsToken));
    assertEq(obolLst.symbol(), "rstOBOL");
    assertEq(obolLst.name(), "Rebasing Staked Obol");
    assertEq(obolLst.owner(), LST_OWNER);
    assertEq(obolLst.payoutAmount(), _lstConfig.initialPayoutAmount);
    assertEq(obolLst.delegateeGuardian(), _lstConfig.initialDelegateeGuardian);
    // assertEq(obolLst.maxOverrideTip(), _lstConfig.maxOverrideTip); // TODO: why not found?
    assertEq(obolLst.minQualifyingEarningPowerBips(), _lstConfig.minQualifyingEarningPowerBips);
  }
}

contract ObolStakerDeployedTest is ObolStakerIntegrationTestBase {
  function getBlockHeightForFork() internal pure override returns (uint256) {
    return 22_318_393; // Block height for mainnet after Obol Staker production deployment
  }

  function setUp() public override {
    super.setUp();
    // initialize addresses for deployed contracts to test
    obolStaker = ObolStaker(0x30641013934ec7625c9e73a4D63aab4201004259);
    calculator = IEarningPowerCalculator(0x5A58Bc950e947383E34325B463586bb57Bea3a34);
    obolLst = RebasingStakedObol(0x1932e815254c53B3Ecd81CECf252A5AC7f0e8BeA);
    autoDelegate = address(0xCa28852B6Fc15EbD95b17c875D5Eb14b08579158);
    deployer = address(0x4413203299bf8bdF59f6399cd9Fe94d321A68822);
  }
}
