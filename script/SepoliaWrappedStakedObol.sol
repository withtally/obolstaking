// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BaseWrappedStakedObolDeploy} from "script/BaseWrappedStakedObol.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SepoliaWrappedStakedObolDeploy is BaseWrappedStakedObolDeploy {
  function _getWrapperConfig() internal virtual override returns (ObolWrapperParams memory) {
    address _expectedWrappedLstAddress =
      vm.computeCreateAddress(deployer, vm.getNonce(deployer) + 1);
    vm.broadcast(deployer);
    IERC20(0x01Fe882DBB791Aa17BbcBb054214ecd3eB809c39).approve(_expectedWrappedLstAddress, 100);
    return BaseWrappedStakedObolDeploy.ObolWrapperParams({
      name: "Wrapped Staked Obol",
      symbol: "wstObol",
      lst: 0xc397DB883fBA93647881e3cc554078c66b21b20c,
      delegatee: 0xC0c2fC4e158b9F51AE484B6bd66BB7185085C40a,
      initialOwner: 0xEAC5F0d4A9a45E1f9FdD0e7e2882e9f60E301156,
      preFundAmount: 100
    });
  }
}
