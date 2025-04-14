// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Staker, IERC20} from "staker/Staker.sol";
import {StakerDelegateSurrogateVotes} from "staker/extensions/StakerDelegateSurrogateVotes.sol";
import {StakerPermitAndStake} from "staker/extensions/StakerPermitAndStake.sol";
import {StakerOnBehalf, EIP712} from "staker/extensions/StakerOnBehalf.sol";
import {IEarningPowerCalculator} from "staker/interfaces/IEarningPowerCalculator.sol";
import {IERC20Staking} from "staker/interfaces/IERC20Staking.sol";

/// @title ObolStaker
/// @author [ScopeLift](https://scopelift.co)
/// @notice Core staking contract for the Obol Collective. Built on top of the Tally Staker
/// contracts. This implementation includes permit functionality for gasless approvals, staking
/// on behalf of other addresses, and delegation of voting power through surrogate contracts.
contract ObolStaker is Staker, StakerDelegateSurrogateVotes, StakerPermitAndStake, StakerOnBehalf {
  /// @notice Initializes the ObolStaker contract with required parameters.
  /// @param _rewardsToken ERC20 token in which rewards will be denominated.
  /// @param _stakeToken Delegable governance token which users will stake to earn rewards.
  /// @param _earningPowerCalculator The contract that will calculate earning power for depositors.
  /// @param _maxBumpTip Maximum tip that can be paid to bumpers for updating earning power.
  /// @param _admin Address which will have permission to manage reward notifiers.
  /// @param _name Name used in the EIP712 domain separator for permit functionality.
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
