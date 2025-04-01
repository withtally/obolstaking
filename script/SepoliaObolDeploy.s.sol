// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {IEarningPowerCalculator} from "staker/interfaces/IEarningPowerCalculator.sol";
import {IdentityEarningPowerCalculator} from "staker/calculators/IdentityEarningPowerCalculator.sol";
import {IERC20Staking} from "staker/interfaces/IERC20Staking.sol";
import {GovLst} from "stGOV/GovLst.sol";
import {BaseObolDeploy as Base} from "script/BaseObolDeploy.sol";
import {ObolTestToken} from "script/ObolTestToken.sol";
import {TransferRewardNotifier} from "staker/notifiers/TransferRewardNotifier.sol";

contract SepoliaObolDeploy is Base {
  ObolTestToken fakeObol;
  TransferRewardNotifier transferNotifier;

  // Rewards to send to the reward notifier after deployment
  uint256 TRANSFER_REWARDS = 5_000_000e18;

  // Works out to 5 Million OBOL per year
  uint256 REWARD_AMOUNT = 410_958.9041097e18;
  uint256 REWARD_INTERVAL = 30 days;

  function _deployEarningPowerCalculator()
    internal
    virtual
    override
    returns (IEarningPowerCalculator)
  {
    vm.broadcast(deployer);
    IdentityEarningPowerCalculator _calculator = new IdentityEarningPowerCalculator();
    return _calculator;
  }

  function _getStakerConfig() internal view virtual override returns (Base.ObolStakerParams memory) {
    return Base.ObolStakerParams({
      rewardsToken: fakeObol,
      stakeToken: IERC20Staking(address(fakeObol)),
      maxBumpTip: 12e18,
      admin: deployer, // Deployer is the admin for the test deployment
      name: "Obol Staker Test"
    });
  }

  function _deployRewardNotifiers() internal virtual override returns (address[] memory) {
    // NOTE: Deployer is the notifier admin for testnet, but it would be the timelock in prod
    vm.broadcast(deployer);
    transferNotifier = new TransferRewardNotifier(staker, REWARD_AMOUNT, REWARD_INTERVAL, deployer);
    address[] memory _return = new address[](1);
    _return[0] = address(transferNotifier);
    return _return;
  }

  function _getLstConfig() internal view virtual override returns (GovLst.ConstructorParams memory) {
    return GovLst.ConstructorParams({
      fixedLstName: "Staked Obol Test",
      fixedLstSymbol: "stOBOLTEST2",
      rebasingLstName: "Rebasing Staked Obol Test",
      rebasingLstSymbol: "rstOBOLTEST2",
      version: "1",
      // Deployed earlier in the script execution
      staker: staker,
      // Simply a burn address
      initialDefaultDelegatee: address(0x0b01),
      initialOwner: deployer,
      // Setting this to something small so that integrators can trigger it frequently for testing
      // purposes. A discussion is warranted on what the real value should be.
      initialPayoutAmount: 100e18,
      initialDelegateeGuardian: deployer,
      // 1 OBOLTEST2
      stakeToBurn: 1e18,
      // 100% since we're using the identity calculator
      minQualifyingEarningPowerBips: 1e4
    });
  }

  function run() public override {
    // Deploy Test OBOL token contract
    vm.broadcast(deployer);
    fakeObol = new ObolTestToken();
    console2.log("Deployed Obol Test Token", address(fakeObol));

    // Perform the deployment of the core system
    super.run();

    // Transfer reward tokens & perform the first notification (testnet only operation)
    vm.broadcast(deployer);
    fakeObol.transfer(address(transferNotifier), TRANSFER_REWARDS);
    console2.log("Transferred to Reward Notifier", TRANSFER_REWARDS);
    vm.broadcast(deployer);
    transferNotifier.notify();
    console2.log("Notified first reward");
  }
}
