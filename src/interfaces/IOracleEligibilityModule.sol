// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title IOracleEligibilityModule
/// @author [ScopeLift](https://scopelift.co)
/// @notice Interface for the oracle eligibility module that determines if a delegate is eligible
/// for earning power.
interface IOracleEligibilityModule {
  /// @notice Returns true if the oracle is paused.
  function isOraclePaused() external view returns (bool);

  /// @notice Returns true if the oracle is stale.
  function isOracleStale() external view returns (bool);

  /// @notice Returns true if the delegate is eligible for earning power.
  /// @param _delegatee The address of the delegate to check.
  function isDelegateeEligible(address _delegatee) external view returns (bool);
}
