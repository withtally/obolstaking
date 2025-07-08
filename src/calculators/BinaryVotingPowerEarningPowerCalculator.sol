// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IEarningPowerCalculator} from "staker/interfaces/IEarningPowerCalculator.sol";
import {IOracleEligibilityModule} from "src/interfaces/IOracleEligibilityModule.sol";

/// @title BinaryVotingPowerEarningPowerCalculator
/// @author [ScopeLift](https://scopelift.co)
/// @notice Calculates earning power based on voting power snapshots and binary eligibility.
/// @dev This contract calculates earning power as a combination of:
///      1. Staker voting power: The square root of the delegatee's voting power at the most
///         recent snapshot block, taken from an IVotes token at fixed update intervals
///      2. Staker eligibility: A binary flag from the oracle eligibility module indicating
///         whether the delegatee is currently eligible to earn rewards
///
///      The final earning power is calculated as:
///      - If eligible (or oracle unavailable): earning_power = sqrt(voting_power_at_snapshot)
///      - If ineligible: earning_power = 0
///
///      Eligibility is evaluated in real time, whereas voting power is updated at
///      fixed intervals. We rely on the oracle to avoid frequent changes in eligibility,
///      as frequent updates would cause earning power to fluctuate and could enable fee
///      griefing when integrated with a staker.

contract BinaryVotingPowerEarningPowerCalculator is Ownable, IEarningPowerCalculator {
  /*///////////////////////////////////////////////////////////////
                          Events
  //////////////////////////////////////////////////////////////*/

  /// @notice Emitted when a new voting power update interval is set.
  /// @param oldVotingPowerUpdateInterval The old voting power update interval.
  /// @param newVotingPowerUpdateInterval The new voting power update interval.
  event VotingPowerUpdateIntervalSet(
    uint48 oldVotingPowerUpdateInterval, uint48 newVotingPowerUpdateInterval
  );

  /// @notice Emitted when a new oracle eligibility module is set.
  /// @param oldOracleEligibilityModule The old oracle eligibility module address.
  /// @param newOracleEligibilityModule The new oracle eligibility module address.
  event OracleEligibilityModuleSet(
    address indexed oldOracleEligibilityModule, address indexed newOracleEligibilityModule
  );

  /*///////////////////////////////////////////////////////////////
                          Errors
  //////////////////////////////////////////////////////////////*/

  /// @notice Thrown when an invalid address is provided.
  error BinaryVotingPowerEarningPowerCalculator__InvalidAddress();

  /// @notice Thrown when an invalid voting power update interval is provided.
  error BinaryVotingPowerEarningPowerCalculator__InvalidVotingPowerUpdateInterval();

  /*///////////////////////////////////////////////////////////////
                        Immutable Storage
  //////////////////////////////////////////////////////////////*/

  /// @notice The voting power token address.
  address public immutable VOTING_POWER_TOKEN;

  /// @notice The block number at which the voting power update starts.
  uint48 public immutable SNAPSHOT_START_BLOCK;

  /*///////////////////////////////////////////////////////////////
                          Storage
  //////////////////////////////////////////////////////////////*/

  /// @notice The time interval after which the voting power is updated.
  uint48 public votingPowerUpdateInterval;

  /// @notice The oracle eligibility module that determines if a delegate qualifies for earning
  /// power.
  IOracleEligibilityModule public oracleEligibilityModule;

  /*///////////////////////////////////////////////////////////////
                            Constructor
  //////////////////////////////////////////////////////////////*/

  /// @notice Initializes the `BinaryVotingPowerEarningPowerCalculator`.
  /// @param _owner The owner of the contract.
  /// @param _oracleEligibilityModule The oracle eligibility module address.
  /// @param _votingPowerToken The voting power token address.
  /// @param _votingPowerUpdateInterval The voting power update interval.
  constructor(
    address _owner,
    address _oracleEligibilityModule,
    address _votingPowerToken,
    uint48 _votingPowerUpdateInterval
  ) Ownable(_owner) {
    if (_votingPowerToken == address(0)) {
      revert BinaryVotingPowerEarningPowerCalculator__InvalidAddress();
    }

    VOTING_POWER_TOKEN = _votingPowerToken;
    SNAPSHOT_START_BLOCK = uint48(block.number);

    _setOracleEligibilityModule(_oracleEligibilityModule);
    _setVotingPowerUpdateInterval(_votingPowerUpdateInterval);
  }

  /*///////////////////////////////////////////////////////////////
                External Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Gets the earning power of a staker.
  /// @param _staker The address whose earning power is being calculated.
  /// @return _earningPower The earning power of the staker.
  /// @dev This function returns the staker's snapshot voting power (square root) if eligible or if
  /// the oracle is unavailable, otherwise returns 0.
  ///      Voting power is snapshotted at fixed intervals, while eligibility is checked in
  /// real-time.
  function getEarningPower(uint256, /* _amountStaked */ address _staker, address /* _delegatee */ )
    external
    view
    returns (uint256 _earningPower)
  {
    _earningPower = _getEarningPower(_staker);
  }

  /// @notice Gets the new earning power of a staker.
  /// @param _staker The address whose earning power is being calculated.
  /// @return _earningPower The earning power of the staker.
  /// @return _isQualifiedForBump Always true; the staker is always qualified for an earning power
  /// bump.
  /// @dev This function returns the staker's snapshot voting power (square root) if eligible or if
  /// the oracle is unavailable, otherwise returns 0.
  ///      The update interval is relied upon to prevent frequent bumping, as earning power can only
  /// change at each interval.
  function getNewEarningPower(
    uint256, /* _amountStaked */
    address _staker,
    address, /* _delegatee */
    uint256 /* _oldEarningPower */
  ) external view returns (uint256 _earningPower, bool _isQualifiedForBump) {
    _earningPower = _getEarningPower(_staker);
    _isQualifiedForBump = true;
  }

  /// @notice Sets the oracle eligibility module.
  /// @param _newOracleEligibilityModule The new oracle eligibility module address.
  function setOracleEligibilityModule(address _newOracleEligibilityModule) external {
    _checkOwner();
    _setOracleEligibilityModule(_newOracleEligibilityModule);
  }

  /// @notice Sets the voting power update interval.
  /// @param _newVotingPowerUpdateInterval The new voting power update interval.
  function setVotingPowerUpdateInterval(uint48 _newVotingPowerUpdateInterval) external {
    _checkOwner();
    _setVotingPowerUpdateInterval(_newVotingPowerUpdateInterval);
  }

  /*///////////////////////////////////////////////////////////////
                        Internal Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Checks if the oracle is stale or paused.
  /// @return bool True if the oracle is stale or paused, false otherwise.
  function _isOracleUnavailable() internal view returns (bool) {
    return oracleEligibilityModule.isOraclePaused() || oracleEligibilityModule.isOracleStale();
  }

  /// @notice Gets the current voting power snapshot block number.
  /// @return _snapshotBlock The block number that represents the most recent voting power snapshot.
  /// @dev The snapshot block is calculated by finding how many complete intervals have passed
  ///      since the start block and multiplying by the interval.
  function _getSnapshotBlock() internal view returns (uint48 _snapshotBlock) {
    uint256 _intervalPassed = (block.number - SNAPSHOT_START_BLOCK) / votingPowerUpdateInterval;
    _snapshotBlock = uint48(SNAPSHOT_START_BLOCK + _intervalPassed * votingPowerUpdateInterval);
  }

  /// @notice Gets the square root of the votes of a delegate at the most recent snapshot block.
  /// @param _delegatee The address of the delegate to query.
  /// @return uint256 The square root of the votes of the delegate at the snapshot block.
  function _getSnapshotVotes(address _delegatee) internal view returns (uint256) {
    return Math.sqrt(IVotes(VOTING_POWER_TOKEN).getPastVotes(_delegatee, _getSnapshotBlock()));
  }

  /// @notice Gets the earning power of a staker.
  /// @param _delegatee The address of the staker to query.
  /// @return uint256 The earning power of the staker.
  /// @dev This function returns the staker's snapshot voting power (square root) if eligible or if
  /// the oracle is unavailable, otherwise returns 0.
  ///      Eligibility is checked in real-time, while voting power is snapshotted at intervals.
  function _getEarningPower(address _delegatee) internal view returns (uint256) {
    if (_isOracleUnavailable() || oracleEligibilityModule.isDelegateeEligible(_delegatee)) {
      return _getSnapshotVotes(_delegatee);
    }
    return 0;
  }

  /// @notice Sets the voting power update interval.
  /// @param _newVotingPowerUpdateInterval The new voting power update interval.
  function _setVotingPowerUpdateInterval(uint48 _newVotingPowerUpdateInterval) internal {
    if (_newVotingPowerUpdateInterval == 0) {
      revert BinaryVotingPowerEarningPowerCalculator__InvalidVotingPowerUpdateInterval();
    }
    emit VotingPowerUpdateIntervalSet(votingPowerUpdateInterval, _newVotingPowerUpdateInterval);
    votingPowerUpdateInterval = _newVotingPowerUpdateInterval;
  }

  /// @notice Sets the oracle eligibility module.
  /// @param _newOracleEligibilityModule The new oracle eligibility module address.
  function _setOracleEligibilityModule(address _newOracleEligibilityModule) internal {
    if (_newOracleEligibilityModule == address(0)) {
      revert BinaryVotingPowerEarningPowerCalculator__InvalidAddress();
    }
    emit OracleEligibilityModuleSet(address(oracleEligibilityModule), _newOracleEligibilityModule);
    oracleEligibilityModule = IOracleEligibilityModule(_newOracleEligibilityModule);
  }
}
