// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {GovLst, IERC20} from "stGOV/GovLst.sol";
import {GovLstPermitAndStake} from "stGOV/extensions/GovLstPermitAndStake.sol";
import {GovLstOnBehalf} from "stGOV/extensions/GovLstOnBehalf.sol";
import {FixedGovLst} from "stGOV/FixedGovLst.sol";
import {FixedStakedObol} from "src/FixedStakedObol.sol";

/// @title RebasingStakedObol
/// @author [ScopeLift](https://scopelift.co)
/// @notice The rebasing variant of the liquid staked OBOL token, i.e. rstOBOL. This contract works
/// in tandem with the fixed balance staked OBOL token, i.e. stOBOL. While the fixed balance stOBOL
/// is the canonical liquid representation of staked OBOL, the two use the same underlying
/// accounting system, which is located in this contract. Unlike stOBOL, which maintains a fixed
/// balance that becomes worth more underlying OBOL tokens overtime, rstOBOL has a dynamic balance
/// function that update automatically. As such, 1 rstOBOL is always equivalent to 1 underlying
/// OBOL.
contract RebasingStakedObol is GovLst, GovLstPermitAndStake, GovLstOnBehalf {
  /// @notice Initializes the rebasing staked OBOL contract with the parameters provided.
  /// @param _params Struct containing the deployment params for this contract. See
  /// GovLst.ConstructorParams for details.
  constructor(GovLst.ConstructorParams memory _params) GovLst(_params) {}

  /// @notice Deploys the fixed balance variant of staked OBOL, i.e. the canonical stOBOL contract.
  /// This method is called during deployment from this contract's constructor.
  /// @param _name The name for the fixed balance liquid stake token.
  /// @param _symbol The symbol for the fixed balance liquid stake token.
  /// @param _lst The address of this contract.
  /// @param _stakeToken The ERC20 token that acts as the staking token.
  /// @param _shareScaleFactor The scale factor applied to shares in this contract.
  function _deployFixedGovLst(
    string memory _name,
    string memory _symbol,
    string memory _version,
    GovLst _lst,
    IERC20 _stakeToken,
    uint256 _shareScaleFactor
  ) internal virtual override returns (FixedGovLst _fixedLst) {
    return new FixedStakedObol(_name, _symbol, _version, _lst, _stakeToken, _shareScaleFactor);
  }
}
