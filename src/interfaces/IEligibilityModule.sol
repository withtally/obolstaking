// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title IEligibilityModule
/// @author [ScopeLift](https://scopelift.co)
/// @notice Interface for the eligibility module that determines if a delegate eligible for earning
/// power.
interface IEligibilityModule {
  /// @notice Returns true if the oracle is paused.
  function isOraclePaused() external view returns (bool);

  /// @notice Returns true if the oracle is stale.
  function isOracleStale() external view returns (bool);

  /// @notice Returns true if the delegate is eligible for earning power.
  /// @param _delegatee The address of the delegate to check.
  function isDelegateeEligible(address _delegatee) external view returns (bool);
}
