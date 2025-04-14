//  SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {FixedGovLst, IERC20} from "stGOV/FixedGovLst.sol";
import {FixedGovLstPermitAndStake} from "stGOV/extensions/FixedGovLstPermitAndStake.sol";
import {FixedGovLstOnBehalf} from "stGOV/extensions/FixedGovLstOnBehalf.sol";
import {GovLst} from "stGOV/GovLst.sol";

/// @title FixedStakedObol
/// @author [ScopeLift](https://scopelift.co)
/// @notice The fixed balance variant of the liquid staked OBOL token, i.e. stOBOL. This contract
/// works in tandem with the rebasing staked OBOL token, i.e. rstOBOL. While this contract is the
/// canonical liquid representation of staked OBOL, the two use the same underlying accounting
/// system, which is located in the rebasing token contract. This contract is deployed by, and
/// interacts with, the rstOBOL contract. Unlike rstOBOL, this contract maintains a fixed balance
/// for stakers, even as rewards are distributed. While the user's balance of stOBOL stays fixed,
/// the number of underlying OBOL tokens they have a claim to grows over time. As such, 1 stOBOL
/// will be worth more and more OBOL over time.
contract FixedStakedObol is FixedGovLst, FixedGovLstPermitAndStake, FixedGovLstOnBehalf {
  /// @notice Initializes the fixed balance staked OBOL contract.
  /// @param _name The name for the fixed balance liquid stake token.
  /// @param _symbol The symbol for the fixed balance liquid stake token.
  /// @param _lst The rebasing LST for which this contract will serve as the fixed balance
  /// counterpart.
  /// @param _stakeToken The ERC20 token that acts as the staking token.
  /// @param _shareScaleFactor The scale factor applied to shares in the rebasing contract.
  constructor(
    string memory _name,
    string memory _symbol,
    string memory _version,
    GovLst _lst,
    IERC20 _stakeToken,
    uint256 _shareScaleFactor
  ) FixedGovLst(_name, _symbol, _version, _lst, _stakeToken, _shareScaleFactor) {}
}
