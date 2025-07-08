// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC6372 as IGovernanceClock} from
  "staker/lib/openzeppelin-contracts/contracts/interfaces/IERC6372.sol";
import {IEarningPowerCalculator} from "staker/interfaces/IEarningPowerCalculator.sol";
import {IOracleEligibilityModule} from "src/interfaces/IOracleEligibilityModule.sol";

/// @title BinaryVotingPowerEarningPowerCalculator
/// @author [ScopeLift](https://scopelift.co)
/// @notice Calculates earning power based on voting power snapshots and binary eligibility.
/// @dev This contract calculates earning power using snapshot-based voting power
///      from an IVotes token, taken at fixed update intervals. If a delegatee is
///      deemed ineligible by the eligibility module, their voting power is zeroed out —
///      unless the oracle is paused or stale, in which case snapshot voting power is used.
///
///      Eligibility is evaluated only at the snapshot interval boundaries, not in real time.
///      Systems integrating this contract may apply bumping logic to compensate
///      delegates who were temporarily penalized due to oracle delays or instability.
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

  /// @notice Emitted when a new eligibility module is set.
  /// @param oldEligibilityModule The old eligibility module address.
  /// @param newEligibilityModule The new eligibility module address.
  event EligibilityModuleSet(
    address indexed oldEligibilityModule, address indexed newEligibilityModule
  );

  /// @notice Emitted when a new governance clock is set.
  /// @param oldGovernanceClock The old governance clock address.
  /// @param newGovernanceClock The new governance clock address.
  event GovernanceClockSet(address indexed oldGovernanceClock, address indexed newGovernanceClock);

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

  /// @notice The clock value at which the voting power snapshot begins.
  uint48 public immutable SNAPSHOT_START;

  /*///////////////////////////////////////////////////////////////
                          Storage
  //////////////////////////////////////////////////////////////*/

  /// @notice The time interval after which the voting power is updated.
  uint48 public votingPowerUpdateInterval;

  /// @notice The oracle eligibility module that determines if a delegate qualifies for earning
  /// power.
  IOracleEligibilityModule public oracleEligibilityModule;

  /// @notice The governance clock that determines the current time.
  IGovernanceClock public governanceClock;

  /*///////////////////////////////////////////////////////////////
                            Constructor
  //////////////////////////////////////////////////////////////*/

  /// @notice Initializes the BinaryVotingPowerEarningPowerCalculator.
  /// @param _owner The owner of the contract.
  /// @param _oracleEligibilityModule The oracle eligibility module address.
  /// @param _votingPowerToken The voting power token address.
  /// @param _votingPowerUpdateInterval The voting power update interval.
  /// @param _governanceClock The governance clock address. Set to address(0) to default to
  /// block.number
  constructor(
    address _owner,
    address _oracleEligibilityModule,
    address _votingPowerToken,
    uint48 _votingPowerUpdateInterval,
    address _governanceClock
  ) Ownable(_owner) {
    if (_votingPowerToken == address(0)) {
      revert BinaryVotingPowerEarningPowerCalculator__InvalidAddress();
    }

    _setOracleEligibilityModule(_oracleEligibilityModule);
    _setVotingPowerUpdateInterval(_votingPowerUpdateInterval);
    _setGovernanceClock(_governanceClock);

    SNAPSHOT_START = clock();
    VOTING_POWER_TOKEN = _votingPowerToken;
  }

  /*///////////////////////////////////////////////////////////////
              Governance Clock Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Returns the current governance clock for this contract.
  /// @dev If a custom governance clock was provided at deployment, this function delegates to it.
  ///      Otherwise, it defaults to `block.number`, making the contract compliant with EIP-6372.
  /// @return currentClock The current clock value (e.g., block number or timestamp).
  function clock() public view override returns (uint48) {
    if (governanceClock == IGovernanceClock(address(this))) return uint48(block.number);
    return governanceClock.clock();
  }

  /// @notice Describes the clock mode used by this contract, as defined by EIP-6372.
  /// @dev Returns "mode=blocknumber" if no external governance clock is set,
  ///      otherwise delegates to the configured `governanceClock`.
  /// @return mode A string describing the clock mode (e.g., "mode=blocknumber" or
  /// "mode=timestamp").
  function CLOCK_MODE() public view override returns (string memory) {
    if (governanceClock == IGovernanceClock(address(this))) return "mode=blocknumber";
    return governanceClock.CLOCK_MODE();
  }

  /*///////////////////////////////////////////////////////////////
              Proxy Eligibility Module Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Gets the earning power of a voter.
  /// @param _staker The address whose voting power is being calculated.
  /// @return _votingPower The voting power of the voter.
  /// @dev This function uses the voter's snapshot voting power at the most recent
  ///      voting power update interval, and returns zero if the delegatee is
  ///      ineligible **unless** the oracle is paused or stale — in which case,
  ///      it still returns the snapshot voting power.
  function getEarningPower(uint256, /* _amountStaked */ address _staker, address /* _delegatee */ )
    external
    view
    returns (uint256 _votingPower)
  {
    _votingPower = _getEarningPower(_staker);
  }

  /// @notice Gets the new earning power of a voter.
  /// @param _staker The address whose voting power is being calculated.
  /// @return _votingPower The voting power of the voter.
  /// @return _isQualifiedForBump Whether the voter is qualified for a bump.
  /// @dev This function uses the voter's snapshot voting power at the most recent
  ///      voting power update interval, and returns zero if the delegatee is
  ///      ineligible **unless** the oracle is paused or stale — in which case,
  ///      it still returns the snapshot voting power.
  function getNewEarningPower(
    uint256, /* _amountStaked */
    address _staker,
    address, /* _delegatee */
    uint256 /* _oldEarningPower */
  ) external view returns (uint256 _votingPower, bool _isQualifiedForBump) {
    _votingPower = _getEarningPower(_staker);
    _isQualifiedForBump = true;
  }

  /*///////////////////////////////////////////////////////////////
                        External Functions
  //////////////////////////////////////////////////////////////*/

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

  /// @notice Sets the governance clock.
  /// @param _newGovernanceClock The new governance clock address.
  function setGovernanceClock(address _newGovernanceClock) external {
    _checkOwner();
    _setGovernanceClock(_newGovernanceClock);
  }

  /// @notice Returns the current effective snapshot clock based on the clock and interval.
  function currentSnapshotClock() external view returns (uint48) {
    return _getSnapshotClock();
  }

  /*///////////////////////////////////////////////////////////////
                        Internal Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Checks if the oracle is stale or paused.
  /// @return bool True if the oracle is stale or paused, false otherwise.
  function _isOracleUnavailable() internal view returns (bool) {
    return oracleEligibilityModule.isOraclePaused() || oracleEligibilityModule.isOracleStale();
  }

  /// @notice Gets the current snapshot clock based on the governance clock.
  /// @return _snapshotClock The clock (e.g., block number or timestamp) representing the most
  /// recent voting power snapshot.
  /// @dev The snapshot clock is calculated by finding how many complete intervals have passed
  ///      since the start clock and multiplying by the interval.
  function _getSnapshotClock() internal view returns (uint48 _snapshotClock) {
    uint256 _intervalsElapsed = (clock() - SNAPSHOT_START) / votingPowerUpdateInterval;
    _snapshotClock = uint48(SNAPSHOT_START + _intervalsElapsed * votingPowerUpdateInterval);
  }

  /// @param _delegatee The address of the delegate to query.
  /// @notice Gets the votes of a delegate at the most recent snapshot clock.
  /// @return uint256 The votes of the delegate at the snapshot clock.
  function _getSnapshotVotes(address _delegatee) internal view returns (uint256) {
    // ASK-TEAM: IVotes.getPastVotes expects a block number, so this always uses
    // block-based snapshots, regardless of the governance clock's mode.
    // If the clock uses timestamps, this mismatch could lead to incorrect behavior.
    return Math.sqrt(IVotes(VOTING_POWER_TOKEN).getPastVotes(_delegatee, _getSnapshotClock()));
  }

  /// @notice Gets the earning power of a delegate.
  /// @param _delegatee The address of the delegate to query.
  /// @return uint256 The earning power of the delegate.
  /// @dev This function returns the earning power of the delegate at the most recent snapshot clock
  ///      if the oracle is unavailable or the delegate is eligible. Otherwise, it returns 0.
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
    emit EligibilityModuleSet(address(oracleEligibilityModule), _newOracleEligibilityModule);
    oracleEligibilityModule = IOracleEligibilityModule(_newOracleEligibilityModule);
  }

  /// @notice Sets the governance clock.
  /// @param _newGovernanceClock The new governance clock address.
  /// @dev If the new governance clock is address(0), the contract will default to using
  /// block.number as the clock and the address of the contract as the governance clock.
  function _setGovernanceClock(address _newGovernanceClock) internal {
    emit GovernanceClockSet(address(governanceClock), _newGovernanceClock);
    if (_newGovernanceClock == address(0)) governanceClock = IGovernanceClock(address(this));
    else governanceClock = IGovernanceClock(_newGovernanceClock);
  }
}
