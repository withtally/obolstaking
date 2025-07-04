// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IEligibilityModule} from "src/interfaces/IEligibilityModule.sol";
import {IEarningPowerCalculator} from "staker/interfaces/IEarningPowerCalculator.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title BinaryVotingPowerCalculator
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
contract BinaryVotingPowerCalculator is Ownable, IEarningPowerCalculator {
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

  /*///////////////////////////////////////////////////////////////
                          Errors
  //////////////////////////////////////////////////////////////*/

  /// @notice Thrown when an invalid address is provided.
  error BinaryVotingPowerCalculator__InvalidAddress();

  /// @notice Thrown when an invalid voting power update interval is provided.
  error BinaryVotingPowerCalculator__InvalidVotingPowerUpdateInterval();

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

  /// @notice The eligibility module that determines if a delegate qualifies for earning power.
  IEligibilityModule public eligibilityModule;

  /*///////////////////////////////////////////////////////////////
                            Constructor
  //////////////////////////////////////////////////////////////*/

  /// @notice Initializes the BinaryVotingPowerCalculator.
  /// @param _owner The owner of the contract.
  /// @param _eligibilityModule The eligibility module address.
  /// @param _votingPowerToken The voting power token address.
  /// @param _votingPowerUpdateInterval The voting power update interval.
  constructor(
    address _owner,
    address _eligibilityModule,
    address _votingPowerToken,
    uint48 _votingPowerUpdateInterval
  ) Ownable(_owner) {
    if (_votingPowerToken == address(0)) revert BinaryVotingPowerCalculator__InvalidAddress();

    VOTING_POWER_TOKEN = _votingPowerToken;
    SNAPSHOT_START_BLOCK = uint48(block.number);

    _setEligibilityModule(_eligibilityModule);
    _setVotingPowerUpdateInterval(_votingPowerUpdateInterval);
  }

  /*///////////////////////////////////////////////////////////////
              Proxy Eligibility Module Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Gets the earning power of a voter.
  /// @param _staker The address who's voting power is being calculated.
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
    _votingPower = _getEffectiveVotingPower(_staker);
  }

  /// @notice Gets the new earning power of a voter.
  /// @param _staker The address who's voting power is being calculated.
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
    _votingPower = _getEffectiveVotingPower(_staker);
    _isQualifiedForBump = true;
  }

  /*///////////////////////////////////////////////////////////////
                        External Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Sets the eligibility module.
  /// @param _newEligibilityModule The new eligibility module address.
  function setEligibilityModule(address _newEligibilityModule) external {
    _checkOwner();
    _setEligibilityModule(_newEligibilityModule);
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
    return eligibilityModule.isOraclePaused() || eligibilityModule.isOracleStale();
  }

  /// @notice Gets the current voting power snapshot block number.
  /// @return _snapshotBlock The block number that represents the most recent voting power snapshot.
  /// @dev The snapshot block is calculated by finding how many complete intervals have passed
  ///      since the start block and multiplying by the interval.
  function _getSnapshotBlock() internal view returns (uint48 _snapshotBlock) {
    uint256 _intervalPassed = (block.number - SNAPSHOT_START_BLOCK) / votingPowerUpdateInterval;
    _snapshotBlock = uint48(SNAPSHOT_START_BLOCK + _intervalPassed * votingPowerUpdateInterval);
  }

  /// @notice Gets the votes of a delegate at the most recent snapshot block.
  /// @param _delegatee The address of the delegate to query.
  /// @return uint256 The votes of the delegate at the snapshot block.
  function _getSnapshotVotes(address _delegatee) internal view returns (uint256) {
    return Math.sqrt(IVotes(VOTING_POWER_TOKEN).getPastVotes(_delegatee, _getSnapshotBlock()));
  }

  /// @notice Gets the effective voting power of a delegate.
  /// @param _delegatee The address of the delegate to query.
  /// @return uint256 The effective voting power of the delegate.
  /// @dev This function returns the voting power of the delegate at the most recent snapshot block
  ///      if the oracle is unavailable or the delegate is eligible. Otherwise, it returns 0.
  function _getEffectiveVotingPower(address _delegatee) internal view returns (uint256) {
    if (_isOracleUnavailable() || eligibilityModule.isDelegateeEligible(_delegatee)) {
      return _getSnapshotVotes(_delegatee);
    }

    return 0;
  }

  /// @notice Sets the voting power update interval.
  /// @param _newVotingPowerUpdateInterval The new voting power update interval.
  function _setVotingPowerUpdateInterval(uint48 _newVotingPowerUpdateInterval) internal {
    if (_newVotingPowerUpdateInterval == 0) {
      revert BinaryVotingPowerCalculator__InvalidVotingPowerUpdateInterval();
    }
    emit VotingPowerUpdateIntervalSet(votingPowerUpdateInterval, _newVotingPowerUpdateInterval);
    votingPowerUpdateInterval = _newVotingPowerUpdateInterval;
  }

  /// @notice Sets the eligibility module.
  /// @param _newEligibilityModule The new eligibility module address.
  function _setEligibilityModule(address _newEligibilityModule) internal {
    if (_newEligibilityModule == address(0)) revert BinaryVotingPowerCalculator__InvalidAddress();
    emit EligibilityModuleSet(address(eligibilityModule), _newEligibilityModule);
    eligibilityModule = IEligibilityModule(_newEligibilityModule);
  }
}
