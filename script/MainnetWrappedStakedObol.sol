// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BaseWrappedStakedObolDeploy} from "script/BaseWrappedStakedObol.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MainnetWrappedStakedObolDeploy is BaseWrappedStakedObolDeploy {
  function _getWrapperConfig() internal virtual override returns (ObolWrapperParams memory) {
    uint256 _prefundAmount = 1e18;

    address _expectedWrappedLstAddress =
      vm.computeCreateAddress(deployer, vm.getNonce(deployer) + 1);
    vm.broadcast(deployer);
    IERC20(0x6590cBBCCbE6B83eF3774Ef1904D86A7B02c2fCC).approve(
      _expectedWrappedLstAddress, _prefundAmount
    ); // Approve for stOBOL
    return BaseWrappedStakedObolDeploy.ObolWrapperParams({
      name: "Wrapped Staked Obol",
      symbol: "wstOBOL",
      lst: 0x1932e815254c53B3Ecd81CECf252A5AC7f0e8BeA, // Rebasing Staked Obol
      delegatee: 0xC0c2fC4e158b9F51AE484B6bd66BB7185085C40a, // Auto-delegate
      initialOwner: 0x42D201CC4d9C1e31c032397F54caCE2f48C1FA72,
      preFundAmount: _prefundAmount
    });
  }
}
