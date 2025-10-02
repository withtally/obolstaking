// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {WrappedGovLst} from "stGOV/WrappedGovLst.sol";
import {Script, console2} from "forge-std/Script.sol";
import {GovLst} from "stGOV/GovLst.sol";

abstract contract BaseWrappedStakedObolDeploy is Script {
  address public deployer;
  uint256 public deployerPrivateKey;

  struct ObolWrapperParams {
    string name;
    string symbol;
    address lst;
    address delegatee;
    address initialOwner;
    uint256 preFundAmount;
  }

  function setUp() public virtual {
    deployerPrivateKey = vm.envOr(
      "DEPLOYER_PRIVATE_KEY",
      uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
    );
    deployer = vm.rememberKey(deployerPrivateKey);

    console2.log("Deploying from", deployer);
  }

  function _getWrapperConfig() internal virtual returns (ObolWrapperParams memory);

  function run() public virtual {
    ObolWrapperParams memory _config = _getWrapperConfig();
    vm.startBroadcast(deployer);
    new WrappedGovLst(
      _config.name,
      _config.symbol,
      GovLst(_config.lst),
      _config.delegatee,
      _config.initialOwner,
      _config.preFundAmount
    );
    vm.stopBroadcast();
  }
}
