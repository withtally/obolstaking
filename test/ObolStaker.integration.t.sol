// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Staker} from "staker/Staker.sol";
import {PercentAssertions} from "staker-test/helpers/PercentAssertions.sol";
import {ObolStaker, IERC20} from "src/ObolStaker.sol";
import {RebasingStakedObol} from "src/RebasingStakedObol.sol";
import {IntegrationTest} from "test/IntegrationTest.sol";
import {MainnetObolDeploy} from "script/MainnetObolDeploy.s.sol";
import {GovLst} from "stGOV/GovLst.sol";

contract ObolStakerDeploymentTest is IntegrationTest {
  // Obol Multisig
  address OBOL_STAKER_ADMIN = 0x42D201CC4d9C1e31c032397F54caCE2f48C1FA72;
  // Tally Multisig
  address LST_OWNER = 0x7E90E03654732ABedF89Faf87f05BcD03ACEeFdC;

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

contract Stake is IntegrationTest, PercentAssertions {
  function testForkFuzz_CorrectlyStakeAndEarnRewardsAfterDuration(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _percentDuration
  ) public {
    vm.assume(_depositor != address(0) && _delegatee != address(0) && _amount != 0);
    vm.assume(_depositor != address(obolStaker));
    vm.assume(_depositor != address(obolStaker.surrogates(deployer)));
    _amount = _dealStakingToken(_depositor, _amount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _percentDuration = bound(_percentDuration, 0, 100);

    vm.startPrank(_depositor);
    IERC20(address(obolStaker.STAKE_TOKEN())).approve(address(obolStaker), _amount);
    ObolStaker.DepositIdentifier _depositId = obolStaker.stake(_amount, _delegatee);
    vm.stopPrank();
    _mintTransferAndNotifyReward(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    // Calculate expected rewards based on percentage of duration and compare with actual unclaimed
    // rewards
    uint256 expectedRewards = (_rewardAmount * _percentDuration) / 100;
    uint256 unclaimedRewards = obolStaker.unclaimedReward(_depositId);
    // FINALLY FIGURED OUT THAT IN THIS CALCULATION WE HAVE TO TAKE INTO ACCOUNT "STAKE TO BURN" IN
    // THE LST DEPLOYMENT!!!!
    assertLteWithinOnePercent(unclaimedRewards, expectedRewards);
  }

  function testForkFuzz_CorrectlyStakeMoreAndEarnRewardsAfterDuration(
    address _depositor,
    uint96 _initialAmount,
    uint96 _additionalAmount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _percentDuration,
    uint256 _eligibilityScore
  ) public {
    vm.assume(_depositor != address(0) && _delegatee != address(0));
    vm.assume(_depositor != address(obolStaker));
    vm.assume(_depositor != address(obolStaker.surrogates(deployer)));
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _percentDuration = bound(_percentDuration, 0, 100);
    _eligibilityScore = _boundEligibilityScore(_eligibilityScore);

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

    // Jump ahead to complete the reward duration
    _jumpAheadByPercentOfRewardDuration(100 - _percentDuration);

    // Calculate expected rewards:
    // 1. Rewards earned with initial amount during first period
    uint256 expectedRewardsPeriod1 =
      (_rewardAmount * _percentDuration * _initialAmount) / (100 * (_initialAmount));
    // 2. Rewards earned with combined amount during second period
    uint256 expectedRewardsPeriod2 = (_rewardAmount * (100 - _percentDuration)) / 100;
    uint256 totalExpectedRewards = expectedRewardsPeriod1 + expectedRewardsPeriod2 + 1;

    // Assert that the unclaimed rewards are within one percent of the expected amount
    assertLteWithinOnePercent(obolStaker.unclaimedReward(_depositId), totalExpectedRewards);
  }
}

contract Unstake is IntegrationTest, PercentAssertions {
  function testForkFuzz_CorrectlyUnstakeAfterDuration(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _withdrawAmount,
    uint256 _percentDuration,
    uint256 _eligibilityScore
  ) public {
    vm.assume(_depositor != address(0) && _delegatee != address(0) && _amount != 0);
    vm.assume(_depositor != address(obolStaker));
    vm.assume(_depositor != address(obolStaker.surrogates(deployer)));
    _amount = _dealStakingToken(_depositor, _amount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _withdrawAmount = bound(_withdrawAmount, 0.1e18, _amount);
    _percentDuration = bound(_percentDuration, 0, 100);
    _eligibilityScore = _boundEligibilityScore(_eligibilityScore);

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
}

contract ClaimRewards is IntegrationTest, PercentAssertions {
  function testForkFuzz_CorrectlyStakeAndClaimRewardsAfterDuration(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _percentDuration,
    uint256 _eligibilityScore
  ) public {
    vm.assume(_depositor != address(0) && _delegatee != address(0) && _amount != 0);
    vm.assume(_depositor != address(obolStaker));
    vm.assume(_depositor != address(obolStaker.surrogates(deployer)));
    _amount = _dealStakingToken(_depositor, _amount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _percentDuration = bound(_percentDuration, 0, 100);
    _eligibilityScore = _boundEligibilityScore(_eligibilityScore);

    vm.startPrank(_depositor);
    IERC20(address(obolStaker.STAKE_TOKEN())).approve(address(obolStaker), _amount);
    ObolStaker.DepositIdentifier _depositId = obolStaker.stake(_amount, _delegatee);
    vm.stopPrank();

    _mintTransferAndNotifyReward(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 oldBalance = IERC20(address(obolStaker.REWARD_TOKEN())).balanceOf(_depositor);

    vm.prank(_depositor);
    obolStaker.claimReward(_depositId);

    uint256 newBalance = IERC20(address(obolStaker.REWARD_TOKEN())).balanceOf(_depositor);

    // Calculate expected rewards based on percentage of duration
    uint256 expectedRewards = (_rewardAmount * _percentDuration) / 100;
    assertLteWithinOnePercent(newBalance - oldBalance, expectedRewards);
    assertEq(obolStaker.unclaimedReward(_depositId), 0);
  }

  function testForkFuzz_CorrectlyUnstakeAndClaimRewardsAfterDuration(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _withdrawAmount,
    uint256 _percentDuration,
    uint256 _eligibilityScore
  ) public {
    vm.skip(true);
    vm.assume(_depositor != address(0) && _delegatee != address(0) && _amount != 0);
    vm.assume(_depositor != address(obolStaker));
    vm.assume(_depositor != address(obolStaker.surrogates(deployer)));
    _amount = _dealStakingToken(_depositor, _amount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _withdrawAmount = bound(_withdrawAmount, 0.1e18, _amount);
    _percentDuration = bound(_percentDuration, 0, 100);
    _eligibilityScore = _boundEligibilityScore(_eligibilityScore);

    vm.startPrank(_depositor);
    IERC20(address(obolStaker.STAKE_TOKEN())).approve(address(obolStaker), _amount);
    ObolStaker.DepositIdentifier _depositId = obolStaker.stake(_amount, _delegatee);
    vm.stopPrank();

    _mintTransferAndNotifyReward(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 oldStakeBalance = IERC20(address(obolStaker.STAKE_TOKEN())).balanceOf(_depositor);
    uint256 oldRewardBalance = IERC20(address(obolStaker.REWARD_TOKEN())).balanceOf(_depositor);

    vm.startPrank(_depositor);
    obolStaker.withdraw(_depositId, _withdrawAmount);
    obolStaker.claimReward(_depositId);
    vm.stopPrank();

    uint256 newStakeBalance = IERC20(address(obolStaker.STAKE_TOKEN())).balanceOf(_depositor);
    uint256 newRewardBalance = IERC20(address(obolStaker.REWARD_TOKEN())).balanceOf(_depositor);

    assertEq(newStakeBalance - oldStakeBalance, _withdrawAmount);

    uint256 expectedRewards = (_rewardAmount * _percentDuration) / 100;
    assertLteWithinOnePercent(newRewardBalance - oldRewardBalance, expectedRewards);
    assertEq(obolStaker.unclaimedReward(_depositId), 0);
  }
}
