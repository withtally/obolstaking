// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEarningPowerCalculator} from "staker/interfaces/IEarningPowerCalculator.sol";
import {DelegateCompensationStaker} from "../../src/DelegateCompensationStaker.sol";
import {Staker} from "staker/Staker.sol";

contract DelegateCompensationStakerHarness is DelegateCompensationStaker {
  constructor(
    IERC20 _rewardToken,
    IEarningPowerCalculator _earningPowerCalculator,
    uint256 _maxBumpTip,
    address _admin
  ) DelegateCompensationStaker(_rewardToken, _earningPowerCalculator, _maxBumpTip, _admin) {}

  function scaledUnclaimedReward(DepositIdentifier _depositId) public view returns (uint256) {
    return _scaledUnclaimedReward(deposits[_depositId]);
  }

  function fetchOrDeploySurrogate(address _delegatee) public pure {
    _fetchOrDeploySurrogate(_delegatee);
  }
}
