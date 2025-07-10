// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {InitDelegateeDeposits, GovLst} from "stGOV/script/InitDelegateeDeposits.s.sol";

contract InitObolDelegateeDeposits is InitDelegateeDeposits {
  // Address of rstOBOL, the _rebasing_ variant, not the canonical stOBOL
  address REBASING_STAKED_OBOL = 0x1932e815254c53B3Ecd81CECf252A5AC7f0e8BeA;

  function filePath() public view virtual override returns (string memory) {
    // A list of all existing OBOL delegatees who have at least two addresses delegating
    // voting weight to them.
    return string.concat(vm.projectRoot(), "/script/obol-delegatees.json");
  }

  function getGovLst() public virtual override returns (GovLst) {
    return GovLst(REBASING_STAKED_OBOL);
  }

  function multicallBatchSize() public pure virtual override returns (uint256) {
    return 50;
  }

  function run() public virtual override {
    super.run();
  }
}
