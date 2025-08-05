// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Staker} from "staker/Staker.sol";
import {IOracleEligibilityModule} from "src/interfaces/IOracleEligibilityModule.sol";
import {DelegateCompensationStaker} from "src/DelegateCompensationStaker.sol";

/// @title OracleDelegateCompensationInitializer
/// @author [ScopeLift](https://scopelift.co)
/// @notice Abstract contract that manages delegate score updates and compensation initialization.
/// @dev This contract bridges the oracle eligibility module with the delegate compensation staker,
/// automatically initializing delegate compensation when they become eligible.
abstract contract OracleDelegateCompensationInitializer is Ownable {
  /// @notice Emitted when the `scoreOracle` address is updated.
  /// @param oldScoreOracle The address of the previous `scoreOracle`.
  /// @param newScoreOracle The address of the new `scoreOracle`.
  event ScoreOracleSet(address indexed oldScoreOracle, address indexed newScoreOracle);

  /// @notice The immutable address of the delegate compensation staker contract.
  address public immutable DELEGATE_COMPENSATION_STAKER;
  /// @notice The oracle eligibility module used to check delegate eligibility.
  IOracleEligibilityModule private ORACLE_ELIGIBILITY_MODULE;
  /// @notice The address with the authority to update delegatee scores.
  address public scoreOracle;

  /// @notice Error thrown when a non-score oracle address tries to call the `updateDelegateeScore`
  /// function.
  /// @param reason The reason for the unauthorized access (e.g., "not oracle").
  /// @param caller The address that attempted the unauthorized call.
  error OracleDelegateCompensationInitializer__Unauthorized(bytes32 reason, address caller);

  /// @notice Initializes the contract with necessary addresses.
  /// @param _delegateCompensationStaker The address of the delegate compensation staker contract.
  /// @param _oracleEligibilityModule The address of the oracle eligibility module.
  /// @param _scoreOracle The initial address authorized to update delegate scores.
  constructor(
    address _delegateCompensationStaker,
    address _oracleEligibilityModule,
    address _scoreOracle
  ) {
    DELEGATE_COMPENSATION_STAKER = _delegateCompensationStaker;
    ORACLE_ELIGIBILITY_MODULE = IOracleEligibilityModule(_oracleEligibilityModule);
    _setScoreOracle(_scoreOracle);
  }

  /// @notice Returns the oracle eligibility module instance.
  /// @return The oracle eligibility module interface.
  function getOracleEligibilityModule() public virtual returns (IOracleEligibilityModule) {
    return ORACLE_ELIGIBILITY_MODULE;
  }

  /// @notice Updates a delegatee's score and initializes their compensation if eligible.
  /// @dev Only callable by the score oracle. Automatically initializes delegate compensation
  /// if the delegate becomes eligible and hasn't been initialized yet.
  /// @param _delegatee The address of the delegate whose score is being updated.
  /// @param _newScore The new score value to set for the delegate.
  function updateDelegateeScore(address _delegatee, uint256 _newScore) public virtual {
    _revertIfNotScoreOracle();
    DelegateCompensationStaker _delegateCompensationStaker =
      DelegateCompensationStaker(DELEGATE_COMPENSATION_STAKER);
    ORACLE_ELIGIBILITY_MODULE.updateDelegateeScore(_delegatee, _newScore);
    if (
      Staker.DepositIdentifier.unwrap(_delegateCompensationStaker.delegateDepositId(_delegatee))
        == 0 && ORACLE_ELIGIBILITY_MODULE.isDelegateeEligible(_delegatee)
    ) _delegateCompensationStaker.initializeDelegateCompensation(_delegatee);
  }

  /// @notice Sets a new address as the score oracle.
  /// @dev This function can only be called by the contract owner.
  /// @param _newScoreOracle The address of the new score oracle contract.
  function setScoreOracle(address _newScoreOracle) public {
    _checkOwner();
    _setScoreOracle(_newScoreOracle);
  }

  /// @notice Reverts if the caller is not the score oracle.
  /// @dev Internal function to enforce score oracle access control.
  function _revertIfNotScoreOracle() internal view {
    if (msg.sender != scoreOracle) {
      revert OracleDelegateCompensationInitializer__Unauthorized("not oracle", msg.sender);
    }
  }

  /// @notice Internal function to set a new score oracle address.
  /// @dev This function updates the scoreOracle address and emits an event.
  /// @param _newScoreOracle The address of the new score oracle.
  function _setScoreOracle(address _newScoreOracle) internal {
    emit ScoreOracleSet(scoreOracle, _newScoreOracle);
    scoreOracle = _newScoreOracle;
  }
}
