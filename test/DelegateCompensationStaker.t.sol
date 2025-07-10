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

    assertEq(
      Staker.DepositIdentifier.unwrap(staker.delegateDepositId(_delegate)),
      Staker.DepositIdentifier.unwrap(_depositId)
    );
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

    assertEq(
      Staker.DepositIdentifier.unwrap(staker.delegateDepositId(_delegate1)),
      Staker.DepositIdentifier.unwrap(_depositId1)
    );
    assertEq(
      Staker.DepositIdentifier.unwrap(staker.delegateDepositId(_delegate2)),
      Staker.DepositIdentifier.unwrap(_depositId2)
    );
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
    Staker.DepositIdentifier depositId = staker.initializeDelegateCompensation(_delegate);
  }

  function testFuzz_RevertIf_DelegateCompensationIsAlreadyInitialized(
    uint256 _earningPower,
    address _delegate
  ) public {
    _assumeValidDelegate(_delegate);
    _earningPower = _boundToRealisticEarningPower(_earningPower);

    calculator.setDelegateEarningPower(_delegate, _earningPower);
    staker.initializeDelegateCompensation(_delegate);
    console2.log("delegate initialized");
    vm.expectRevert(
      abi.encodeWithSelector(
        DelegateCompensationStaker.DelegateCompensation__AlreadyInitialized.selector, _delegate
      )
    );
    staker.initializeDelegateCompensation(_delegate);
  }
}

contract GetDelegateCompensation is DelegateCompensationStakerTest {
  function testFuzz_ReturnsZeroDepositIfDelegateCompensationIsNotInitiated(address _delegate)
    public
  {
    Staker.Deposit memory _deposit = staker.getDelegateCompensation(_delegate);
    assertEq(Staker.DepositIdentifier.unwrap(staker.delegateDepositId(_delegate)), 0);
    assertEq(_deposit.balance, 0);
    assertEq(_deposit.owner, address(0));
    assertEq(_deposit.earningPower, 0);
    assertEq(_deposit.delegatee, address(0));
    assertEq(_deposit.claimer, address(0));
    assertEq(_deposit.rewardPerTokenCheckpoint, 0);
    assertEq(_deposit.scaledUnclaimedRewardCheckpoint, 0);
  }

  function testFuzz_ReturnsDepositOfSingleInitializedDelegateCompensation(
    uint256 _earningPower,
    address _delegate,
    uint256 _amount,
    uint256 _durationPercent
  ) public {
    _assumeValidDelegate(_delegate);
    _earningPower = _boundToRealisticEarningPower(_earningPower);

    calculator.setDelegateEarningPower(_delegate, _earningPower);
    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    _amount = _boundToRealisticReward(_amount);
    _mintAndNotifyRewards(_amount);

    _durationPercent = bound(_durationPercent, 0, 100);
    _jumpAheadByPercentOfRewardDuration(_durationPercent);

    Staker.Deposit memory _deposit = staker.getDelegateCompensation(_delegate);
    assertEq(
      Staker.DepositIdentifier.unwrap(staker.delegateDepositId(_delegate)),
      Staker.DepositIdentifier.unwrap(_depositId)
    );
    assertEq(_deposit.balance, 0);
    assertEq(_deposit.owner, _delegate);
    assertEq(_deposit.earningPower, _earningPower);
    assertEq(_deposit.delegatee, _delegate);
    assertEq(_deposit.claimer, _delegate);
    assertEq(_deposit.rewardPerTokenCheckpoint, staker.rewardPerTokenAccumulatedCheckpoint());
    assertEq(_deposit.scaledUnclaimedRewardCheckpoint, 0);
  }

  function testFuzz_ReturnsDepositOfMultipleInitializedDelegateCompensation(
    address _delegate1,
    address _delegate2,
    uint256 _earningPower1,
    uint256 _earningPower2,
    uint256 _amount,
    uint256 _durationPercent
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

    _amount = _boundToRealisticReward(_amount);
    _mintAndNotifyRewards(_amount);

    _durationPercent = bound(_durationPercent, 0, 100);
    _jumpAheadByPercentOfRewardDuration(_durationPercent);

    Staker.Deposit memory _deposit1 = staker.getDelegateCompensation(_delegate1);
    Staker.Deposit memory _deposit2 = staker.getDelegateCompensation(_delegate2);

    assertEq(
      Staker.DepositIdentifier.unwrap(staker.delegateDepositId(_delegate1)),
      Staker.DepositIdentifier.unwrap(_depositId1)
    );
    assertEq(_deposit1.balance, 0);
    assertEq(_deposit1.owner, _delegate1);
    assertEq(_deposit1.earningPower, _earningPower1);
    assertEq(_deposit1.delegatee, _delegate1);
    assertEq(_deposit1.claimer, _delegate1);
    assertEq(_deposit1.rewardPerTokenCheckpoint, staker.rewardPerTokenAccumulatedCheckpoint());
    assertEq(_deposit1.scaledUnclaimedRewardCheckpoint, 0);

    assertEq(
      Staker.DepositIdentifier.unwrap(staker.delegateDepositId(_delegate2)),
      Staker.DepositIdentifier.unwrap(_depositId2)
    );
    assertEq(_deposit2.balance, 0);
    assertEq(_deposit2.owner, _delegate2);
    assertEq(_deposit2.earningPower, _earningPower2);
    assertEq(_deposit2.delegatee, _delegate2);
    assertEq(_deposit2.claimer, _delegate2);
    assertEq(_deposit2.rewardPerTokenCheckpoint, staker.rewardPerTokenAccumulatedCheckpoint());
    assertEq(_deposit2.scaledUnclaimedRewardCheckpoint, 0);
  }

  function testFuzz_ReturnsUpdatedDepositAfterEarningPowerBump(
    address _delegate,
    uint256 _initialEarningPower,
    uint256 _newEarningPower,
    uint256 _amount,
    uint256 _durationPercent,
    address _caller
  ) public {
    _assumeValidDelegate(_delegate);
    _initialEarningPower = _boundToRealisticEarningPower(_initialEarningPower);
    _newEarningPower = _boundToRealisticEarningPower(_newEarningPower);
    vm.assume(_newEarningPower > _initialEarningPower);

    vm.assume(_caller != address(0));

    calculator.setDelegateEarningPower(_delegate, _initialEarningPower);
    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    calculator.setDelegateEarningPower(_delegate, _newEarningPower);

    _amount = _boundToRealisticReward(_amount);
    _mintAndNotifyRewards(_amount);

    _durationPercent = bound(_durationPercent, 0, 100);
    _jumpAheadByPercentOfRewardDuration(_durationPercent);

    vm.prank(_caller);
    staker.bumpEarningPower(_depositId, _caller, 0);

    Staker.Deposit memory _deposit = staker.getDelegateCompensation(_delegate);
    assertEq(
      Staker.DepositIdentifier.unwrap(staker.delegateDepositId(_delegate)),
      Staker.DepositIdentifier.unwrap(_depositId)
    );
    assertEq(_deposit.balance, 0);
    assertEq(_deposit.owner, _delegate);
    assertEq(_deposit.earningPower, _newEarningPower);
    assertEq(_deposit.delegatee, _delegate);
    assertEq(_deposit.claimer, _delegate);
    assertEq(_deposit.rewardPerTokenCheckpoint, staker.rewardPerTokenAccumulatedCheckpoint());
    assertEq(_deposit.scaledUnclaimedRewardCheckpoint, staker.scaledUnclaimedReward(_depositId));
  }
}
