// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import {FixedGovLst, IERC20} from "stGOV/FixedGovLst.sol";
import {FixedGovLstPermitAndStake} from "stGOV/extensions/FixedGovLstPermitAndStake.sol";
import {FixedGovLstOnBehalf} from "stGOV/extensions/FixedGovLstOnBehalf.sol";
import {GovLst} from "stGOV/GovLst.sol";

contract FixedObolLst is FixedGovLst, FixedGovLstPermitAndStake, FixedGovLstOnBehalf {
  constructor(
    string memory _name,
    string memory _symbol,
    string memory _version,
    GovLst _lst,
    IERC20 _stakeToken,
    uint256 _shareScaleFactor
  ) FixedGovLst(_name, _symbol, _version, _lst, _stakeToken, _shareScaleFactor) {}
}
