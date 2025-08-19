// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BaseObolDelegateCompensationDeploy as Base} from
  "script/BaseObolDelegateCompensationDeploy.sol";
import {BinaryEligibilityOracleEarningPowerCalculator} from
  "staker/calculators/BinaryEligibilityOracleEarningPowerCalculator.sol";
import {IEarningPowerCalculator} from "staker/interfaces/IEarningPowerCalculator.sol";

contract MainnetObolDelegateCompensationDeploy is Base {
  function setUp() public virtual override {
    super.setUp();
    REWARD_INTERVAL = 30 days; // Arbitrary interval
    REWARD_AMOUNT = 165_000e18 / 6; // Aribitrary amount
  }

  function _deployEarningPowerCalculator(address)
    internal
    virtual
    override
    returns (IEarningPowerCalculator)
  {
    address _owner = 0x42D201CC4d9C1e31c032397F54caCE2f48C1FA72; // TODO: Check ownwer of staker
    address _scoreOracle = address(0);
    uint256 _staleOracleWindow = 0;
    address _oraclePauseGuardian = address(0);
    uint256 _delegateeScoreEligibilityThreshold = 65;
    uint256 _updateEligibilityDelay = 0; // Not used
    return new BinaryEligibilityOracleEarningPowerCalculator(
      _owner,
      _scoreOracle,
      _staleOracleWindow,
      _oraclePauseGuardian,
      _delegateeScoreEligibilityThreshold,
      _updateEligibilityDelay
    );
  }

  function _getObolDelegateCompensationConfig()
    internal
    virtual
    override
    returns (DelegateCompensationConfig memory)
  {
    return DelegateCompensationConfig({
      owner: deployer,
      votingPowerToken: 0x0B010000b7624eb9B3DfBC279673C76E9D29D5F7,
      votingPowerUpdateInterval: 3 weeks, // 72 hours
      scoreOracle: 0xC82Abf706378a88137040B03806489FD524B981c, // Curia test
      rewardToken: IERC20(0x0B010000b7624eb9B3DfBC279673C76E9D29D5F7),
      maxBumpTip: 10e18, // arbitrary
      admin: deployer
    });
  }
}
