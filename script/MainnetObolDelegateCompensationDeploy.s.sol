// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BaseObolDelegateCompensationDeploy as Base} from
  "script/BaseObolDelegateCompensationDeploy.sol";
import {BinaryEligibilityOracleEarningPowerCalculator} from
  "staker/calculators/BinaryEligibilityOracleEarningPowerCalculator.sol";
import {IEarningPowerCalculator} from "staker/interfaces/IEarningPowerCalculator.sol";
import {DelegateCompensationStaker} from "src/DelegateCompensationStaker.sol";
import {RewardTokenNotifierBase} from "staker/notifiers/RewardTokenNotifierBase.sol";
import {TransferRewardNotifier} from "staker/notifiers/TransferRewardNotifier.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract MainnetObolDelegateCompensationDeploy is Base {
   address OWNER = 0x42D201CC4d9C1e31c032397F54caCE2f48C1FA72;
  function setUp() public virtual override {
    super.setUp();
    REWARD_INTERVAL = 30 days; // Arbitrary interval
    REWARD_AMOUNT = 165_000e18 / 6; // Aribitrary amount
  }

  function _deployEarningPowerCalculator(address)
    internal
    virtual
    override
    returns (BinaryEligibilityOracleEarningPowerCalculator)
  {
    /// Deployer must update the score oracle and owner which is handled by the base script
    address _scoreOracle = address(0);
    uint256 _staleOracleWindow = 3.5 weeks;
    address _oraclePauseGuardian = 0xEDdffe7cF10f1D31cd7A7416172165EFD6430A93;
    uint256 _delegateeScoreEligibilityThreshold = 65;
    uint256 _updateEligibilityDelay = 0; // Not used
    vm.broadcast();
    return new BinaryEligibilityOracleEarningPowerCalculator(
      deployer,
      _scoreOracle,
      _staleOracleWindow,
      _oraclePauseGuardian,
      _delegateeScoreEligibilityThreshold,
      _updateEligibilityDelay
    );
  }

  function _deployRewardNotifier(DelegateCompensationStaker _delegateComp, IERC20)
    internal
    override
    returns (RewardTokenNotifierBase)
  {
    vm.broadcast(deployer);
    TransferRewardNotifier _transferNotifier =
      new TransferRewardNotifier(_delegateComp, REWARD_AMOUNT, REWARD_INTERVAL, OWNER);

    vm.broadcast(deployer);
    _delegateComp.setRewardNotifier(address(_transferNotifier), true);
    return _transferNotifier;
  }

  function _getObolDelegateCompensationConfig()
    internal
    virtual
    override
    returns (DelegateCompensationConfig memory)
  {
    address _scoreOracle = 0x033bF3608C9DbBfa05Ec1fD784E3763B9b9DCbe7;
    return DelegateCompensationConfig({
      owner: OWNER,
      votingPowerToken: 0x0B010000b7624eb9B3DfBC279673C76E9D29D5F7,
      votingPowerUpdateInterval: 3 weeks,
      scoreOracle: _scoreOracle, // Curia test
      rewardToken: IERC20(0x0B010000b7624eb9B3DfBC279673C76E9D29D5F7),
      maxBumpTip: 10e18, // matches staker
        // https://etherscan.io/address/0x30641013934ec7625c9e73a4d63aab4201004259#readContract
      admin: OWNER
    });
  }
}
