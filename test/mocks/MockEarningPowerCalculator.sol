// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IEarningPowerCalculator} from "staker/interfaces/IEarningPowerCalculator.sol";

/// @title MockEarningPowerCalculator
/// @author [Scopelift](https://scopelift.co)
/// @notice Mock Earning Power Calculator for testing Delegate Compensation Staker
contract MockEarningPowerCalculator is IEarningPowerCalculator {
  /// @notice Configurable earning power for specific delegates
  mapping(address delegatee => uint256 earningPower) public delegateEarningPower;

  /// @notice Helper method to manually set earning power for a specific delegate
  /// @param _delegate The address of the delegate
  /// @param _earningPower The earning power value to set for the delegate
  function setDelegateEarningPower(address _delegate, uint256 _earningPower) external {
    delegateEarningPower[_delegate] = _earningPower;
  }

  /// @inheritdoc IEarningPowerCalculator
  function getEarningPower(uint256, /* _amountStaked */ address, /* _staker */ address _delegatee)
    external
    view
    override
    returns (uint256 _earningPower)
  {
    _earningPower = delegateEarningPower[_delegatee];
  }

  /// @inheritdoc IEarningPowerCalculator
  function getNewEarningPower(
    uint256, /* _amountStaked */
    address, /* _staker */
    address _delegatee,
    uint256 /* _oldEarningPower */
  ) external view override returns (uint256 _newEarningPower, bool _isQualifiedForBump) {
    _newEarningPower = delegateEarningPower[_delegatee];
    _isQualifiedForBump = true;
  }
}
