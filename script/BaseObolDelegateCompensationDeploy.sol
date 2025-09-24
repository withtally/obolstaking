// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {ObolBinaryVotingWeightEarningPowerCalculator} from
  "src/ObolBinaryVotingWeightEarningPowerCalculator.sol";
import {DelegateCompensationStaker} from "src/DelegateCompensationStaker.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IEarningPowerCalculator} from "staker/interfaces/IEarningPowerCalculator.sol";
import {TransferRewardNotifier} from "staker/notifiers/TransferRewardNotifier.sol";
import {RewardTokenNotifierBase} from "staker/notifiers/RewardTokenNotifierBase.sol";
import {BinaryEligibilityOracleEarningPowerCalculator} from
  "staker/calculators/BinaryEligibilityOracleEarningPowerCalculator.sol";

abstract contract BaseObolDelegateCompensationDeploy is Script {
  address public deployer;
  uint256 public deployerPrivateKey;
  uint256 public REWARD_INTERVAL; // Arbitrary interval
  uint256 public REWARD_AMOUNT; // Aribitrary amount

  struct DelegateCompensationConfig {
    address owner;
    address votingPowerToken;
    uint48 votingPowerUpdateInterval;
    address scoreOracle;
    IERC20 rewardToken;
    uint256 maxBumpTip;
    address admin;
  }

  function setUp() public virtual {
    deployerPrivateKey = vm.envOr(
      "DEPLOYER_PRIVATE_KEY",
      uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
    );
    deployer = vm.rememberKey(deployerPrivateKey);

    console2.log("Deploying from", deployer);
  }

  function _getObolDelegateCompensationConfig()
    internal
    virtual
    returns (DelegateCompensationConfig memory);

  function _deployEarningPowerCalculator(address _delegateComp)
    internal
    virtual
    returns (BinaryEligibilityOracleEarningPowerCalculator);

  function _deployRewardNotifier(DelegateCompensationStaker _delegateComp, IERC20 _rewardToken)
    internal
    virtual
    returns (RewardTokenNotifierBase);

  function run()
    public
    virtual
    returns (DelegateCompensationStaker, ObolBinaryVotingWeightEarningPowerCalculator)
  {
    DelegateCompensationConfig memory _delegateCompParams = _getObolDelegateCompensationConfig();

    vm.broadcast(deployer);
    DelegateCompensationStaker _delegateComp = new DelegateCompensationStaker(
      _delegateCompParams.rewardToken,
      IEarningPowerCalculator(deployer),
      _delegateCompParams.maxBumpTip,
      deployer
    );

    BinaryEligibilityOracleEarningPowerCalculator _oracleEligibilityModule =
      _deployEarningPowerCalculator(address(_delegateComp));

    vm.broadcast(deployer);
    ObolBinaryVotingWeightEarningPowerCalculator _epc = new ObolBinaryVotingWeightEarningPowerCalculator(
      _delegateCompParams.owner,
      address(_oracleEligibilityModule),
      _delegateCompParams.votingPowerToken,
      _delegateCompParams.votingPowerUpdateInterval,
      address(_delegateComp),
      _delegateCompParams.scoreOracle
    );

    vm.broadcast(deployer);
    _oracleEligibilityModule.setScoreOracle(address(_epc));

    vm.broadcast(deployer);
    _oracleEligibilityModule.transferOwnership(address(_delegateCompParams.owner));

    vm.broadcast(deployer);
    _delegateComp.setEarningPowerCalculator(address(_epc));

    _deployRewardNotifier(_delegateComp, _delegateCompParams.rewardToken);

    vm.broadcast(deployer);
    _delegateComp.setAdmin(_delegateCompParams.admin);
    return (_delegateComp, _epc);
  }
}
