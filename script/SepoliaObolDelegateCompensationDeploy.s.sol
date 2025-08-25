// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {BaseObolDelegateCompensationDeploy as Base} from
  "script/BaseObolDelegateCompensationDeploy.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IEarningPowerCalculator} from "staker/interfaces/IEarningPowerCalculator.sol";
import {BinaryEligibilityOracleEarningPowerCalculator} from
  "staker/calculators/BinaryEligibilityOracleEarningPowerCalculator.sol";
import {DelegateCompensationStaker} from "src/DelegateCompensationStaker.sol";
import {RewardTokenNotifierBase} from "staker/notifiers/RewardTokenNotifierBase.sol";
import {TransferRewardNotifier} from "staker/notifiers/TransferRewardNotifier.sol";


contract SepoliaObolDelegateCompensationDeploy is Base {
  function setUp() public virtual override {
    super.setUp();
    REWARD_INTERVAL = 30 days; // Arbitrary interval
    REWARD_AMOUNT = 10_000e18; // Aribitrary amount
  }

  function _deployEarningPowerCalculator(address /* delegateComp */ )
    internal
    pure
    override
    returns (BinaryEligibilityOracleEarningPowerCalculator)
  {
    return BinaryEligibilityOracleEarningPowerCalculator(0xcD40E49f4AbA59F24cfa3Aa23E785688FDAd4908);
  }

  function _deployRewardNotifier(DelegateCompensationStaker _delegateComp, IERC20 _rewardToken)
    internal
    virtual
	override
    returns (RewardTokenNotifierBase)
  {
    vm.broadcast(deployer);
    TransferRewardNotifier _transferNotifier =
      new TransferRewardNotifier(_delegateComp, REWARD_AMOUNT, REWARD_INTERVAL, deployer);

    vm.broadcast(deployer);
    _rewardToken.transfer(address(_transferNotifier), REWARD_AMOUNT);
    console2.log("Transferred to Reward Notifier", REWARD_AMOUNT);

    vm.broadcast(deployer);
    _delegateComp.setRewardNotifier(address(_transferNotifier), true);

    vm.broadcast(deployer);
    _transferNotifier.notify();
    console2.log("Notified first reward");

    return _transferNotifier;
  }



  function _getObolDelegateCompensationConfig()
    internal
    virtual
    override
    returns (DelegateCompensationConfig memory)
  {
    return DelegateCompensationConfig({
      owner: deployer,
      votingPowerToken: 0x830B162043b41908840aC8328Ce867CB6B5C2c74,
      votingPowerUpdateInterval: 259_200, // 72 hours
      scoreOracle: 0xC82Abf706378a88137040B03806489FD524B981c, // Curia test
      rewardToken: IERC20(0x830B162043b41908840aC8328Ce867CB6B5C2c74),
      maxBumpTip: 10e18, // arbitrary
      admin: deployer
    });
  }
}
