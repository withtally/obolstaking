// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {DelegateCompensationStakerHarness} from "../harnesses/DelegateCompensationStakerHarness.sol";
import {Staker} from "staker/Staker.sol";
import {MockEarningPowerCalculator} from "test/mocks/MockEarningPowerCalculator.sol";
import {ERC20Fake} from "staker-test/fakes/ERC20Fake.sol";
import {PercentAssertions} from "staker-test/helpers/PercentAssertions.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DelegateCompensationStakerTest is Test, PercentAssertions {
  DelegateCompensationStakerHarness public staker;
  MockEarningPowerCalculator public calculator;
  ERC20Fake public rewardToken;

  address public admin = makeAddr("admin");
  address public rewardNotifier = makeAddr("rewardNotifier");
  uint256 public constant MAX_BUMP_TIP = 10e18;

  function setUp() public virtual {
    rewardToken = new ERC20Fake();
    calculator = new MockEarningPowerCalculator();

    staker = new DelegateCompensationStakerHarness(
      IERC20(address(rewardToken)), calculator, MAX_BUMP_TIP, admin
    );

    vm.startPrank(admin);
    staker.setRewardNotifier(rewardNotifier, true);
    vm.stopPrank();
  }

  function _mintAndNotifyRewards(uint256 amount) internal {
    rewardToken.mint(address(staker), amount);
    vm.prank(rewardNotifier);
    staker.notifyRewardAmount(amount);
  }

  function _min(uint256 _leftValue, uint256 _rightValue) internal pure returns (uint256) {
    return _leftValue > _rightValue ? _rightValue : _leftValue;
  }

  function _jumpAhead(uint256 _seconds) public {
    vm.warp(block.timestamp + _seconds);
  }

  function _jumpAheadByPercentOfRewardDuration(uint256 _percent) public {
    uint256 _seconds = (_percent * staker.REWARD_DURATION()) / 100;
    _jumpAhead(_seconds);
  }

  /// @dev Helper to bound earning power to reasonable voting power range
  function _boundToRealisticEarningPower(uint256 _earningPower)
    internal
    pure
    returns (uint256 _boundedEarningPower)
  {
    _boundedEarningPower = bound(_earningPower, 0, 1e27);
  }

  /// @dev Helper to bound reward amounts to valid range
  function _boundToRealisticReward(uint256 _rewardAmount)
    public
    pure
    returns (uint256 _boundedRewardAmount)
  {
    _boundedRewardAmount = bound(_rewardAmount, 200e6, 10_000_000e18);
  }

  function assertEq(Staker.DepositIdentifier a, Staker.DepositIdentifier b) internal pure {
    assertEq(Staker.DepositIdentifier.unwrap(a), Staker.DepositIdentifier.unwrap(b));
  }

  /// @dev Helper to filter out invalid delegate addresses
  function _assumeValidDelegate(address _delegate) internal view {
    vm.assume(_delegate != address(0));
    vm.assume(_delegate != address(staker));
    vm.assume(_delegate != address(calculator));
    vm.assume(_delegate != address(rewardToken));
  }
}
