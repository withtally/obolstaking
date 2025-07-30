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
        DelegateCompensationStaker.DelegateCompensationStaker__AlreadyInitialized.selector,
        _delegate
      )
    );
    staker.initializeDelegateCompensation(_delegate);
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
    vm.expectRevert(
      DelegateCompensationStaker.DelegateCompensationStaker__MethodNotSupported.selector
    );
    staker.stake(_amount, _delegate, _claimer);
  }
}

contract StakeMore is DelegateCompensationStakerTest {
  function testFuzz_RevertIf_StakeMoreIsCalled(uint256 _depositId, uint256 _amount) public {
    vm.expectRevert(
      DelegateCompensationStaker.DelegateCompensationStaker__MethodNotSupported.selector
    );
    staker.stakeMore(Staker.DepositIdentifier.wrap(_depositId), _amount);
  }
}

contract Withdraw is DelegateCompensationStakerTest {
  function testFuzz_RevertIf_WithdrawIsCalled(uint256 _depositId, uint256 _amount) public {
    vm.expectRevert(
      DelegateCompensationStaker.DelegateCompensationStaker__MethodNotSupported.selector
    );
    staker.withdraw(Staker.DepositIdentifier.wrap(_depositId), _amount);
  }
}

contract AlterDelegatee is DelegateCompensationStakerTest {
  function testFuzz_RevertIf_AlterDelegateeIsCalled(uint256 _depositId, address _newDelegatee)
    public
  {
    vm.expectRevert(
      DelegateCompensationStaker.DelegateCompensationStaker__MethodNotSupported.selector
    );
    staker.alterDelegatee(Staker.DepositIdentifier.wrap(_depositId), _newDelegatee);
  }
}

contract Surrogates is DelegateCompensationStakerTest {
  function testFuzz_RevertIf_SurrogatesIsCalled(address _delegate) public {
    vm.expectRevert(
      DelegateCompensationStaker.DelegateCompensationStaker__MethodNotSupported.selector
    );
    staker.surrogates(_delegate);
  }
}

contract _FetchOrDeploySurrogate is DelegateCompensationStakerTest {
  function testFuzz_RevertIf_FetchOrDeploySurrogatesIsCalled(address _delegate) public {
    vm.expectRevert(
      DelegateCompensationStaker.DelegateCompensationStaker__MethodNotSupported.selector
    );
    staker.fetchOrDeploySurrogate(_delegate);
  }
}
