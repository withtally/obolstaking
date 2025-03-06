// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {Deploy} from "script/Deploy.s.sol";
import {ObolStaker} from "src/ObolStaker.sol";

contract ObolStakerTest is Test, Deploy {
  ObolStaker staker;

  function setUp() public {}
}
