// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {IEarningPowerCalculator} from "staker/interfaces/IEarningPowerCalculator.sol";
import {IdentityEarningPowerCalculator} from "staker/calculators/IdentityEarningPowerCalculator.sol";
import {IERC20Staking} from "staker/interfaces/IERC20Staking.sol";
import {BaseObolDeploy as Base} from "script/BaseObolDeploy.sol";
import {ObolTestToken} from "script/ObolTestToken.sol";

contract SepoliaObolDeploy is Base {
  ObolTestToken fakeObol;

  function _getOrDeployEarningPowerCalculator() internal virtual override returns (IEarningPowerCalculator) {
    return new IdentityEarningPowerCalculator();
  }

  function _getStakerConfig() internal virtual override view returns (Base.ObolStakerParams memory) {
    return Base.ObolStakerParams({
      rewardsToken: fakeObol,
      stakeToken: IERC20Staking(address(fakeObol)),
      maxBumpTip: 12e18,
      admin: msg.sender, // Deployer is the admin for the test deployment
      name: "Obol Staker"
    });
  }

  function run() public override {
    vm.broadcast();
    fakeObol = new ObolTestToken();

    console2.log("Deployed Obol Test Token", address(fakeObol));

    super.run();
  }
}
