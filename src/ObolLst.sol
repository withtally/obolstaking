// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import {GovLst, IERC20} from "stGOV/GovLst.sol";
import {GovLstPermitAndStake} from "stGOV/extensions/GovLstPermitAndStake.sol";
import {GovLstOnBehalf} from "stGOV/extensions/GovLstOnBehalf.sol";
import {FixedGovLst} from "stGOV/FixedGovLst.sol";
import {FixedObolLst} from "src/FixedObolLst.sol";

contract ObolLst is GovLst, GovLstPermitAndStake, GovLstOnBehalf {
  constructor(GovLst.ConstructorParams memory _params) GovLst(_params) {}

  function _deployFixedGovLst(
    string memory _name,
    string memory _symbol,
    string memory _version,
    GovLst _lst,
    IERC20 _stakeToken,
    uint256 _shareScaleFactor
  ) internal virtual override returns (FixedGovLst _fixedLst) {
    return new FixedObolLst(_name, _symbol, _version, _lst, _stakeToken, _shareScaleFactor);
  }
}
