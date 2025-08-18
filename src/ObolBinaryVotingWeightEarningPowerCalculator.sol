// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OracleDelegateCompensationInitializer} from "src/OracleDelegateCompensationInitializer.sol";
import {BinaryVotingWeightEarningPowerCalculator} from
  "src/calculators/BinaryVotingWeightEarningPowerCalculator.sol";
import {IOracleEligibilityModule} from "src/interfaces/IOracleEligibilityModule.sol";

/// @title ObolBinaryVotingWeightEarningPowerCalculator
/// @author [ScopeLift](https://scopelift.co)
/// @notice A `BinaryVotingWeightEarningPowerCalculator` that initializes delegate
/// compensation deposits when scores are updated on the underlying oracle eligibility module.
/// @dev In most set ups this earning power calculator will be the oracle on the oracle
/// eligibility module, and the actual oracle will be the `scoreOracle` on this contract.
contract ObolBinaryVotingWeightEarningPowerCalculator is
  Ownable,
  OracleDelegateCompensationInitializer,
  BinaryVotingWeightEarningPowerCalculator
{
  /// @param _owner The address that is able to call protected setter methods.
  /// @param _oracleEligibilityModule The address of the oracle eligibility module for delegate
  /// eligibility checks.
  /// @param _votingPowerToken The address of the token used to calculate voting power.
  /// @param _votingPowerUpdateInterval The time interval between voting power updates.
  /// @param _delegateCompensationStaker The address of the delegate compensation staker contract.
  /// @param _scoreOracle The address authorized to update delegate scores.
  constructor(
    address _owner,
    address _oracleEligibilityModule,
    address _votingPowerToken,
    uint48 _votingPowerUpdateInterval,
    address _delegateCompensationStaker,
    address _scoreOracle
  )
    OracleDelegateCompensationInitializer(_delegateCompensationStaker, _scoreOracle)
    BinaryVotingWeightEarningPowerCalculator(
      _owner,
      _oracleEligibilityModule,
      _votingPowerToken,
      _votingPowerUpdateInterval
    )
  {}

  function getOracleEligibilityModule() public virtual override returns (IOracleEligibilityModule) {
    return oracleEligibilityModule;
  }
}
