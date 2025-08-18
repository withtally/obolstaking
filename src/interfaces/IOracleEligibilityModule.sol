// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IOracleEligibilityModule
/// @author [ScopeLift](https://scopelift.co)
/// @notice Interface for the oracle eligibility module that determines if a delegate is eligible
/// for earning power.
interface IOracleEligibilityModule {
  /// @notice The data structure accepted as an argument to `updateDelegateeScores`.
  /// @param delegatee The address of the delegatee whose score is being updated.
  /// @param newScore The new score to be assigned to the delegatee.
  struct DelegateeScoreUpdate {
    address delegatee;
    uint256 newScore;
  }

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

  /// @notice Updates the eligibility scores of multiple delegatees in a single transaction.
  /// @dev This function can only be called by the authorized `scoreOracle` address.
  /// @dev If the oracle is paused, the update will be reverted.
  /// @dev If any of the delegatees' scores is locked, the update will be reverted.
  /// @dev Updates are processed sequentially. If the same delegatee appears multiple times in the
  /// array, the last update will be applied.
  /// @dev An empty array can be passed in by the oracle in order to update the
  /// `lastOracleUpdateTime` keeping the oracle fresh without updating any scores.
  /// @param _delegateeScoreUpdates An array of DelegateeScoreUpdate structs containing delegatee
  /// addresses and their new scores.
  function updateDelegateeScores(DelegateeScoreUpdate[] calldata _delegateeScoreUpdates) external;
}
