// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title MockVotingPowerToken
/// @author [ScopeLift](https://scopelift.co)
/// @notice Mock Voting Power Token for testing voting power calculations
contract MockVotingPowerToken {
  /// @notice Mapping to store balances for testing
  mapping(address => uint256) private _balances;

  /// @notice Mapping to store past votes for testing
  mapping(address => mapping(uint256 => uint256)) private _pastVotes;

  /// @notice Set past votes for a specific account and timepoint
  /// @param account The account address
  /// @param timepoint The timepoint
  /// @param votes The number of votes to set
  function setPastVotes(address account, uint256 timepoint, uint256 votes) external {
    _pastVotes[account][timepoint] = votes;
  }

  /// @notice Get past votes for an account at a specific timepoint
  /// @param account The account address
  /// @param timepoint The timepoint
  /// @return uint256 The number of votes at that timepoint
  function getPastVotes(address account, uint256 timepoint) external view returns (uint256) {
    // If no specific past votes are set, return current balance
    if (_pastVotes[account][timepoint] == 0) return balanceOf(account);
    return _pastVotes[account][timepoint];
  }

  /// @notice Get the balance of an account
  /// @param account The account address
  /// @return uint256 The balance of the account
  function balanceOf(address account) public view returns (uint256) {
    return _balances[account];
  }

  /// @notice Set the balance of an account
  /// @param account The account address
  /// @param balance The balance to set
  function setBalanceOf(address account, uint256 balance) external {
    _balances[account] = balance;
  }
}
