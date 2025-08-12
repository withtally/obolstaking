// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {BaseObolDelegateCompensationDeploy as Base} from
  "script/BaseObolDelegateCompensationDeploy.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract SepoliaObolDelegateCompensationDeploy is Base {
  function _getObolDelegateCompensationConfig()
    internal
    virtual
    override
    returns (DelegateCompensationConfig memory)
  {
    return DelegateCompensationConfig({
      owner: deployer,
      oracleEligibilityModule: 0xcD40E49f4AbA59F24cfa3Aa23E785688FDAd4908, // Deploye BOEEPC
      votingPowerToken: 0x830B162043b41908840aC8328Ce867CB6B5C2c74,
      votingPowerUpdateInterval: 259_200, // 72 hours
      scoreOracle: 0xC82Abf706378a88137040B03806489FD524B981c, // Curia test
      rewardToken: IERC20(0x830B162043b41908840aC8328Ce867CB6B5C2c74),
      maxBumpTip: 10e18, // arbitrary
      admin: deployer
    });
  }
}
