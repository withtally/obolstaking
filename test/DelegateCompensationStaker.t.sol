// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {console2} from "forge-std/Test.sol";
import {DelegateCompensationStaker} from "../src/DelegateCompensationStaker.sol";
import {DelegateCompensationStakerTest} from "test/helpers/DelegateCompensationStakerTest.sol";
import {Staker} from "staker/Staker.sol";

contract InitializeDelegateCompensation is DelegateCompensationStakerTest {
  function testFuzz_InitializeSingleDelegateCompensation(uint256 _earningPower, address _delegate)
    public
  {
    _assumeValidDelegate(_delegate);

    _earningPower = _boundToRealisticEarningPower(_earningPower);
    calculator.setDelegateEarningPower(_delegate, _earningPower);

    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    assertEq(staker.delegateDepositId(_delegate), _depositId);
    assertEq(Staker.DepositIdentifier.unwrap(_depositId), 1);
    assertEq(staker.depositorTotalEarningPower(_delegate), _earningPower);
  }

  function testFuzz_InitializeMultipleDelegateCompensation(
    uint256 _earningPower1,
    uint256 _earningPower2,
    address _delegate1,
    address _delegate2
  ) public {
    _assumeValidDelegate(_delegate1);
    _assumeValidDelegate(_delegate2);
    vm.assume(_delegate1 != _delegate2);
    _earningPower1 = _boundToRealisticEarningPower(_earningPower1);
    _earningPower2 = _boundToRealisticEarningPower(_earningPower2);

    calculator.setDelegateEarningPower(_delegate1, _earningPower1);
    calculator.setDelegateEarningPower(_delegate2, _earningPower2);

    Staker.DepositIdentifier _depositId1 = staker.initializeDelegateCompensation(_delegate1);
    Staker.DepositIdentifier _depositId2 = staker.initializeDelegateCompensation(_delegate2);

    assertEq(staker.delegateDepositId(_delegate1), _depositId1);
    assertEq(staker.delegateDepositId(_delegate2), _depositId2);
    assertEq(Staker.DepositIdentifier.unwrap(_depositId1), 1);
    assertEq(Staker.DepositIdentifier.unwrap(_depositId2), 2);
    assertEq(staker.depositorTotalEarningPower(_delegate1), _earningPower1);
    assertEq(staker.depositorTotalEarningPower(_delegate2), _earningPower2);
  }

  function testFuzz_EmitsAnEventWhenADelegateIsInitialized(uint256 _earningPower, address _delegate)
    public
  {
    _assumeValidDelegate(_delegate);

    _earningPower = _boundToRealisticEarningPower(_earningPower);
    calculator.setDelegateEarningPower(_delegate, _earningPower);

    vm.expectEmit();
    emit DelegateCompensationStaker.DelegateCompensation__Initialized(
      _delegate, Staker.DepositIdentifier.wrap(1), _earningPower
    );
    staker.initializeDelegateCompensation(_delegate);
  }

  function testFuzz_RevertIf_DelegateCompensationIsAlreadyInitialized(
    uint256 _earningPower,
    address _delegate
  ) public {
    _assumeValidDelegate(_delegate);
    _earningPower = _boundToRealisticEarningPower(_earningPower);

    calculator.setDelegateEarningPower(_delegate, _earningPower);
    staker.initializeDelegateCompensation(_delegate);
    vm.expectRevert(
      abi.encodeWithSelector(
        DelegateCompensationStaker.DelegateCompensation__AlreadyInitialized.selector, _delegate
      )
    );
    staker.initializeDelegateCompensation(_delegate);
  }
}

contract SetAdmin is DelegateCompensationStakerTest {
  function testFuzz_AdminCanSetNewAdmin(address _newAdmin) public {
    vm.assume(_newAdmin != address(0));

    vm.expectEmit();
    emit Staker.AdminSet(admin, _newAdmin);

    vm.prank(admin);
    staker.setAdmin(_newAdmin);

    assertEq(staker.admin(), _newAdmin);
  }
}

contract SetEarningPowerCalculator is DelegateCompensationStakerTest {
  function testFuzz_AdminCanSetEarningPowerCalculator(address _newCalculator) public {
    vm.assume(_newCalculator != address(0));

    vm.expectEmit();
    emit Staker.EarningPowerCalculatorSet(address(calculator), _newCalculator);

    vm.prank(admin);
    staker.setEarningPowerCalculator(_newCalculator);

    assertEq(address(staker.earningPowerCalculator()), _newCalculator);
  }
}

contract SetMaxBumpTip is DelegateCompensationStakerTest {
  function testFuzz_AdminCanSetMaxBumpTip(uint256 _newMaxBumpTip) public {
    vm.expectEmit();
    emit Staker.MaxBumpTipSet(MAX_BUMP_TIP, _newMaxBumpTip);

    vm.prank(admin);
    staker.setMaxBumpTip(_newMaxBumpTip);

    assertEq(staker.maxBumpTip(), _newMaxBumpTip);
  }
}

contract SetRewardNotifier is DelegateCompensationStakerTest {
  function testFuzz_AdminCanSetRewardNotifier(address _notifier, bool _isEnabled) public {
    vm.expectEmit();
    emit Staker.RewardNotifierSet(_notifier, _isEnabled);

    vm.prank(admin);
    staker.setRewardNotifier(_notifier, _isEnabled);

    assertEq(staker.isRewardNotifier(_notifier), _isEnabled);
  }
}

contract SetClaimFeeParameters is DelegateCompensationStakerTest {
  function testFuzz_AdminCanSetClaimFeeParameters(
    DelegateCompensationStaker.ClaimFeeParameters memory _newParams
  ) public {
    vm.assume(_newParams.feeCollector != address(0));
    _newParams.feeAmount = uint96(bound(_newParams.feeAmount, 0, staker.MAX_CLAIM_FEE()));

    (uint96 _initialFeeAmount, address _initialFeeCollector) = staker.claimFeeParameters();

    vm.expectEmit();
    emit Staker.ClaimFeeParametersSet(
      _initialFeeAmount, _newParams.feeAmount, _initialFeeCollector, _newParams.feeCollector
    );

    vm.prank(admin);
    staker.setClaimFeeParameters(_newParams);

    (uint96 _newFeeAmount, address _newFeeCollector) = staker.claimFeeParameters();
    assertEq(_newFeeAmount, _newParams.feeAmount);
    assertEq(_newFeeCollector, _newParams.feeCollector);
  }
}

contract LastTimeRewardDistributed is DelegateCompensationStakerTest {
  function testFuzz_ReturnsTheBlockTimestampAfterARewardNotification(
    uint256 _amount,
    uint256 _durationPercent
  ) public {
    _amount = _boundToRealisticReward(_amount);
    _mintAndNotifyRewards(_amount);

    _durationPercent = bound(_durationPercent, 0, 100);
    _jumpAheadByPercentOfRewardDuration(_durationPercent);

    assertEq(staker.lastTimeRewardDistributed(), block.timestamp);
  }
}

contract RewardPerTokenAccumulated is DelegateCompensationStakerTest {
  function testFuzz_RewardPerTokenAccumulatedIncreasesOverTime(
    uint256 _rewardAmount,
    uint256 _durationPercent,
    address _delegate,
    uint256 _earningPower
  ) public {
    _assumeValidDelegate(_delegate);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _earningPower = _boundToRealisticEarningPower(_earningPower);
    _durationPercent = bound(_durationPercent, 1, 100);
    vm.assume(_earningPower != 0);

    calculator.setDelegateEarningPower(_delegate, _earningPower);
    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    uint256 initialRewardPerToken = staker.rewardPerTokenAccumulated();

    _mintAndNotifyRewards(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_durationPercent);

    uint256 newRewardPerToken = staker.rewardPerTokenAccumulated();
    if (_earningPower == 0) {
      assertEq(newRewardPerToken, 0);
    } else {
      uint256 expectedRewardPerToken = (_rewardAmount * _durationPercent * staker.SCALE_FACTOR())
        / (100 * staker.totalEarningPower());
      assertLteWithinOnePercent(newRewardPerToken, expectedRewardPerToken);
    }
  }
}

contract UnclaimedReward is DelegateCompensationStakerTest {
  function testFuzz_CalculatesCorrectEarningsForASingleDelegate(
    uint256 _earningPower,
    uint256 _rewardAmount,
    address _delegate,
    uint256 _duration
  ) public {
    _assumeValidDelegate(_delegate);
    _earningPower = _boundToRealisticEarningPower(_earningPower);
    vm.assume(_earningPower != 0);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    calculator.setDelegateEarningPower(_delegate, _earningPower);
    _duration = bound(_duration, 0, 100);

    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    _mintAndNotifyRewards(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_duration);

    uint256 _unclaimedReward = staker.unclaimedReward(_depositId);
    assertLteWithinOnePercent(_unclaimedReward, _percentOf(_rewardAmount, _duration));
  }

  function testFuzz_CalculatesCorrectEarningsForMultipleDelegates(
    address _delegate1,
    address _delegate2,
    uint256 _earningPower1,
    uint256 _earningPower2,
    uint256 _rewardAmount,
    uint256 _duration
  ) public {
    _assumeValidDelegate(_delegate1);
    _assumeValidDelegate(_delegate2);
    vm.assume(_delegate1 != _delegate2);
    _earningPower1 = _boundToRealisticEarningPower(_earningPower1);
    _earningPower2 = _boundToRealisticEarningPower(_earningPower2);
    vm.assume(_earningPower1 != 0);
    vm.assume(_earningPower2 != 0);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    calculator.setDelegateEarningPower(_delegate1, _earningPower1);
    calculator.setDelegateEarningPower(_delegate2, _earningPower2);
    _duration = bound(_duration, 0, 100);

    Staker.DepositIdentifier _depositId1 = staker.initializeDelegateCompensation(_delegate1);
    Staker.DepositIdentifier _depositId2 = staker.initializeDelegateCompensation(_delegate2);

    _mintAndNotifyRewards(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_duration);

    uint256 _unclaimedReward1 = staker.unclaimedReward(_depositId1);
    uint256 _unclaimedReward2 = staker.unclaimedReward(_depositId2);
    uint256 _expectedReward1 =
      (_percentOf(_rewardAmount, _duration) * _earningPower1) / staker.totalEarningPower();
    uint256 _expectedReward2 =
      (_percentOf(_rewardAmount, _duration) * _earningPower2) / staker.totalEarningPower();

    assertLteWithinOnePercent(_unclaimedReward1, _expectedReward1);
    assertLteWithinOnePercent(_unclaimedReward2, _expectedReward2);
    assertLteWithinOnePercent(
      _expectedReward1 + _expectedReward2, _percentOf(_rewardAmount, _duration)
    );
  }
}

contract AlterClaimer is DelegateCompensationStakerTest {
  function testFuzz_DelegateCanAlterClaimerSuccessfully(
    uint256 _earningPower,
    address _delegate,
    address _claimer
  ) public {
    _assumeValidDelegate(_delegate);
    vm.assume(_claimer != _delegate);
    vm.assume(_claimer != address(0));
    _earningPower = _boundToRealisticEarningPower(_earningPower);
    calculator.setDelegateEarningPower(_delegate, _earningPower);

    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    (,, uint96 _initialEarningPower, address _initialDelegatee, address _initialClaimer,,) =
      staker.deposits(_depositId);
    assertEq(_initialClaimer, _delegate);
    assertEq(_initialDelegatee, _delegate);

    uint256 _currentEarningPower = calculator.getEarningPower(0, _delegate, _delegate);
    vm.expectEmit(true, true, true, true);
    emit Staker.ClaimerAltered(_depositId, _delegate, _claimer, _currentEarningPower);

    vm.prank(_delegate);
    staker.alterClaimer(_depositId, _claimer);

    (,,,, address _newClaimer,,) = staker.deposits(_depositId);
    assertEq(_claimer, _newClaimer);
  }
}

contract ClaimReward is DelegateCompensationStakerTest {
  function testFuzz_ASingleDelegateReceivesCompensationWhenClaiming(
    uint256 _earningPower,
    uint256 _rewardAmount,
    address _delegate,
    uint256 _duration
  ) public {
    _assumeValidDelegate(_delegate);
    _earningPower = _boundToRealisticEarningPower(_earningPower);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    calculator.setDelegateEarningPower(_delegate, _earningPower);
    _duration = bound(_duration, 0, 100);

    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    _mintAndNotifyRewards(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_duration);

    uint256 _initialBalance = rewardToken.balanceOf(_delegate);
    uint256 _unclaimedReward = staker.unclaimedReward(_depositId);

    vm.prank(_delegate);
    staker.claimReward(_depositId);

    assertEq(_initialBalance, 0);
    assertEq(rewardToken.balanceOf(_delegate), _initialBalance + _unclaimedReward);
    assertEq(staker.unclaimedReward(_depositId), 0);
  }
}

contract BumpEarningPower is DelegateCompensationStakerTest {
  function testFuzz_BumpsTheDelegateEarningPowerUp(
    uint256 _initialEarningPower,
    uint256 _newEarningPower,
    address _delegate,
    address _tipReceiver,
    uint256 _requestedTip
  ) public {
    _assumeValidDelegate(_delegate);
    vm.assume(_tipReceiver != _delegate);
    vm.assume(_tipReceiver != address(0));

    _initialEarningPower = _boundToRealisticEarningPower(_initialEarningPower);
    _newEarningPower = _boundToRealisticEarningPower(_newEarningPower);
    vm.assume(_initialEarningPower != _newEarningPower);

    calculator.setDelegateEarningPower(_delegate, _initialEarningPower);

    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    _mintAndNotifyRewards(_boundToRealisticReward(1000e18));
    _jumpAheadByPercentOfRewardDuration(50);

    _requestedTip = bound(_requestedTip, 0, _min(MAX_BUMP_TIP, staker.unclaimedReward(_depositId)));
    calculator.setDelegateEarningPower(_delegate, _newEarningPower);
    staker.bumpEarningPower(_depositId, _tipReceiver, _requestedTip);

    (,, uint96 _finalEarningPower,,,,) = staker.deposits(_depositId);
    assertEq(_finalEarningPower, _newEarningPower);
  }
}

contract Stake is DelegateCompensationStakerTest {
  function testFuzz_RevertIf_StakeIsCalled(uint256 _amount, address _delegate) public {
    vm.expectRevert();
    staker.stake(_amount, _delegate);
  }

  function testFuzz_RevertIf_StakeWithClaimerIsCalled(
    uint256 _amount,
    address _delegate,
    address _claimer
  ) public {
    vm.expectRevert(DelegateCompensationStaker.DelegateCompensation__MethodNotSupported.selector);
    staker.stake(_amount, _delegate, _claimer);
  }
}

contract StakeMore is DelegateCompensationStakerTest {
  function testFuzz_RevertIf_StakeMoreIsCalled(uint256 _depositId, uint256 _amount) public {
    vm.expectRevert(DelegateCompensationStaker.DelegateCompensation__MethodNotSupported.selector);
    staker.stakeMore(Staker.DepositIdentifier.wrap(_depositId), _amount);
  }
}

contract Withdraw is DelegateCompensationStakerTest {
  function testFuzz_RevertIf_WithdrawIsCalled(uint256 _depositId, uint256 _amount) public {
    vm.expectRevert(DelegateCompensationStaker.DelegateCompensation__MethodNotSupported.selector);
    staker.withdraw(Staker.DepositIdentifier.wrap(_depositId), _amount);
  }
}

contract AlterDelegatee is DelegateCompensationStakerTest {
  function testFuzz_RevertIf_AlterDelegateeIsCalled(uint256 _depositId, address _newDelegatee)
    public
  {
    vm.expectRevert(DelegateCompensationStaker.DelegateCompensation__MethodNotSupported.selector);
    staker.alterDelegatee(Staker.DepositIdentifier.wrap(_depositId), _newDelegatee);
  }
}

contract Surrogate is DelegateCompensationStakerTest {
  function testFuzz_RevertIf_SurrogatesIsCalled(address _delegate) public {
    vm.expectRevert(DelegateCompensationStaker.DelegateCompensation__MethodNotSupported.selector);
    staker.surrogates(_delegate);
  }
}
