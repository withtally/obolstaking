//  SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BinaryEligibilityOracleEarningPowerCalculator} from
  "staker/calculators/BinaryEligibilityOracleEarningPowerCalculator.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

// 1. Add virtual method to the delegatee score
contract ObolBinaryEligibilityEarningPowerCalculator is
  BinaryEligibilityOracleEarningPowerCalculator
{
  using Checkpoints for Checkpoints.Trace208;

  Checkpoints.Trace208 internal _totalVotingPower;
  uint48 public votingPowerUpdateInterval;
  uint48 public immutable SNAPSHOT_START_BLOCK;
  address public VOTING_POWER_TOKEN;

  error ERC6372InconsistentClock();

  mapping(address delegate => Checkpoints.Trace208) votingPowerCheckpoints;

  // Stopped here
  constructor(
    address _owner,
    address _votingPowerToken,
    uint48 _votingPowerUpdateInterval,
    address _scoreOracle,
    uint256 _staleOracleWindow,
    address _oraclePauseGuardian,
    uint256 _delegateeScoreEligibilityThreshold,
    uint256 _updateEligibilityDelay
  )
    BinaryEligibilityOracleEarningPowerCalculator(
      _owner,
      _scoreOracle,
      _staleOracleWindow,
      _oraclePauseGuardian,
      _delegateeScoreEligibilityThreshold,
      _updateEligibilityDelay
    )
  {
    if (_votingPowerToken == address(0)) revert();

    SNAPSHOT_START_BLOCK = uint48(block.number);

    VOTING_POWER_TOKEN = _votingPowerToken;
    _setVotingPowerUpdateInterval(_votingPowerUpdateInterval);
  }

  function clock() public view virtual returns (uint48) {
    return Time.blockNumber();
  }

  /**
   * @dev Machine-readable description of the clock as specified in EIP-6372.
   */
  // solhint-disable-next-line func-name-mixedcase
  function CLOCK_MODE() public view virtual returns (string memory) {
    // Check that the clock was not modified
    if (clock() != Time.blockNumber()) revert ERC6372InconsistentClock();
    return "mode=blocknumber&from=default";
  }

  // 1. Should handle the case where the oracle is stale
  // 2. Should handle the case where, If we fallback then udpates should
  //  be prevented
  // 3.
  function updateDelegateVotingPower(address _delegate) external {
    _updateDelegateVotingPower(_delegate);
  }

  function totalVotingPower() external view returns (Checkpoints.Trace208 memory) {
    return _totalVotingPower;
  }

  function _updateDelegateVotingPower(address _delegate) internal {
    uint256 _votingPower = _getSnapshotVotes(_delegate);
    Checkpoints.Trace208 storage _voteCheckpoints = votingPowerCheckpoints[_delegate];
    uint208 _latestTotalVotingPower = _totalVotingPower.latest();
    _voteCheckpoints.push(clock(), SafeCast.toUint208(_votingPower));
    votingPowerCheckpoints[_delegate] = _voteCheckpoints;
    _totalVotingPower.push(clock(), SafeCast.toUint208(_latestTotalVotingPower + _votingPower));
  }

  function _getSnapshotVotes(address _delegatee) internal view returns (uint256) {
    return Math.sqrt(IVotes(VOTING_POWER_TOKEN).getPastVotes(_delegatee, _getSnapshotBlock()));
  }

  function _getSnapshotBlock() internal view returns (uint48 _snapshotBlock) {
    uint256 _intervalPassed = (block.number - SNAPSHOT_START_BLOCK) / votingPowerUpdateInterval;
    _snapshotBlock = uint48(SNAPSHOT_START_BLOCK + _intervalPassed * votingPowerUpdateInterval);
  }

  function _setVotingPowerUpdateInterval(uint48 _newVotingPowerUpdateInterval) internal {
    if (_newVotingPowerUpdateInterval == 0) revert();
    // emit VotingPowerUpdateIntervalSet(votingPowerUpdateInterval, _newVotingPowerUpdateInterval);
    votingPowerUpdateInterval = _newVotingPowerUpdateInterval;
  }
}
