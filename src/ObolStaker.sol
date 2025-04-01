// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Staker, IERC20} from "staker/Staker.sol";
import {StakerDelegateSurrogateVotes} from "staker/extensions/StakerDelegateSurrogateVotes.sol";
import {StakerPermitAndStake} from "staker/extensions/StakerPermitAndStake.sol";
import {StakerOnBehalf, EIP712} from "staker/extensions/StakerOnBehalf.sol";
import {IEarningPowerCalculator} from "staker/interfaces/IEarningPowerCalculator.sol";
import {IERC20Staking} from "staker/interfaces/IERC20Staking.sol";

contract ObolStaker is Staker, StakerDelegateSurrogateVotes, StakerPermitAndStake, StakerOnBehalf {
  constructor(
    IERC20 _rewardsToken,
    IERC20Staking _stakeToken,
    IEarningPowerCalculator _earningPowerCalculator,
    uint256 _maxBumpTip,
    address _admin,
    string memory _name
  )
    Staker(_rewardsToken, _stakeToken, _earningPowerCalculator, _maxBumpTip, _admin)
    StakerDelegateSurrogateVotes(_stakeToken)
    StakerPermitAndStake(_stakeToken)
    EIP712(_name, "1")
  {
    MAX_CLAIM_FEE = 4e18;
    _setClaimFeeParameters(ClaimFeeParameters({feeAmount: 0, feeCollector: address(0)}));
  }
}
