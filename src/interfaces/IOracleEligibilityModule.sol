// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

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

  /// @notice Updates the eligibility score of a delegatee.
  /// @param _delegatee The address of the delegatee whose score is being updated.
  /// @param _newScore The new score to be assigned to the delegatee.
  function updateDelegateeScore(address _delegatee, uint256 _newScore) external;
}
