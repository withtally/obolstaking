// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {Staker, IERC20} from "staker/Staker.sol";
import {IEarningPowerCalculator} from "staker/interfaces/IEarningPowerCalculator.sol";
import {IERC20Staking} from "staker/interfaces/IERC20Staking.sol";
import {ObolStaker} from "src/ObolStaker.sol";

abstract contract BaseObolDeploy is Script {
  struct ObolStakerParams {
    IERC20 rewardsToken;
    IERC20Staking stakeToken;
    uint256 maxBumpTip;
    address admin;
    string name;
  }

  function _getOrDeployEarningPowerCalculator() internal virtual returns (IEarningPowerCalculator);

  function _getStakerConfig() internal virtual view returns (ObolStakerParams memory);

  function run() public virtual {
    IEarningPowerCalculator _calculator = _getOrDeployEarningPowerCalculator();
    ObolStakerParams memory _stakerParams = _getStakerConfig();

    vm.broadcast();
    ObolStaker _staker = new ObolStaker(
      _stakerParams.rewardsToken,
      _stakerParams.stakeToken,
      _calculator,
      _stakerParams.maxBumpTip,
      _stakerParams.admin,
      _stakerParams.name
    );

    console2.log("Deployed Obol Staker: ", address(_staker));
  }
}