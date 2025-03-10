// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

/// @notice Test Token used for onchain testing of the ObolStaker system.
contract ObolTestToken is ERC20Votes, ERC20Permit {
  string private constant NAME = "Obol Staker Test Token";
  string private constant SYMBOL = "OBOLTEST";
  uint256 private constant MINT_AMOUNT = 357_000_000e18;

  constructor() ERC20(NAME, SYMBOL) ERC20Permit(NAME) {
    _mint(msg.sender, MINT_AMOUNT);
  }

  function nonces(address owner)
    public
    view
    virtual
    override(Nonces, ERC20Permit)
    returns (uint256)
  {
    return ERC20Permit.nonces(owner);
  }

  function _update(address from, address to, uint256 value)
    internal
    virtual
    override(ERC20, ERC20Votes)
  {
    ERC20Votes._update(from, to, value);
  }
}
