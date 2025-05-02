// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {ObolStaker, IERC20} from "src/ObolStaker.sol";
import {RebasingStakedObol} from "src/RebasingStakedObol.sol";
import {IEarningPowerCalculator} from "staker/interfaces/IEarningPowerCalculator.sol";

contract IntegrationTest is Test {
  address deployer;
  ObolStaker obolStaker;
  RebasingStakedObol obolLst;
  IEarningPowerCalculator calculator;
  address autoDelegate;

  uint256 constant REWARD_DURATION = 30 days;
  uint256 constant SCALE_FACTOR = 1e36;

  address constant OBOL_TOKEN_ADDRESS = 0x0B010000b7624eb9B3DfBC279673C76E9D29D5F7;
  uint256 constant DEPLOYER_DEAL_AMOUNT = (1e18 * 2) + 5_000_000e18;

  function _assumeSafeAddress(address _address) internal view {
    vm.assume(_address != address(0));
    vm.assume(_address != address(obolStaker.REWARD_TOKEN()));
    vm.assume(_address != address(obolStaker.STAKE_TOKEN()));
    vm.assume(_address != address(obolStaker));
    vm.assume(_address != address(autoDelegate));
    vm.assume(_address != address(obolStaker.surrogates(deployer)));
    vm.assume(_address != address(obolStaker.surrogates(address(autoDelegate))));
  }

  function _dealStakingToken(address _recipient, uint96 _amount) internal returns (uint96) {
    // Bound amount to reasonable values
    _amount = uint96(bound(_amount, 0.1e18, 1e18));
    deal(address(obolStaker.STAKE_TOKEN()), _recipient, _amount);
    return _amount;
  }

  function _boundToRealisticReward(uint256 _rewardAmount) internal pure returns (uint256) {
    // Use much more conservative bounds to prevent overflow
    return bound(_rewardAmount, 1e18, 1_000_000e18); // Max 1M tokens
  }

  function _boundEligibilityScore(uint256 _score) internal pure returns (uint256) {
    return bound(_score, 50, 100);
  }

  function _jumpAheadByPercentOfRewardDuration(uint256 _percent) internal {
    _percent = bound(_percent, 0, 100);
    vm.warp(block.timestamp + (REWARD_DURATION * _percent) / 100);
  }

  function _mintTransferAndNotifyReward(uint256 _rewardAmount) internal {
    // Bound the reward amount to realistic values
    _rewardAmount = _boundToRealisticReward(_rewardAmount);

    // Get the admin from the deployment script
    address admin = obolStaker.admin();
    address rewardNotifier = makeAddr("rewardNotifier");

    // Set up the reward notifier
    vm.prank(admin);
    obolStaker.setRewardNotifier(rewardNotifier, true);

    // Use deal with the bounded amount
    deal(address(obolStaker.REWARD_TOKEN()), rewardNotifier, _rewardAmount);

    // Transfer tokens to the staking contract and notify
    vm.startPrank(rewardNotifier);
    IERC20(address(obolStaker.REWARD_TOKEN())).transfer(address(obolStaker), _rewardAmount);
    obolStaker.notifyRewardAmount(_rewardAmount);
    vm.stopPrank();
  }
}
