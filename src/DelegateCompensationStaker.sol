// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Staker} from "staker/Staker.sol";
import {DelegationSurrogate} from "staker/DelegationSurrogate.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/// @title DelegateCompensationStaker
/// @author [ScopeLift](https://scopelift.co)
/// @notice A specialized staking contract that determines and distributes delegate compensation
/// purely based on earning power.
/// @dev This contract extends the base Staker to implement a delegate compensation system where
/// governance delegates earn compensation proportional to their earning power.
/// @dev Unlike traditional staking, this system:
/// - Creates reward deposits for delegates via initializeDelegateCompensation()
/// - Uses earning power calculator rather than staked token amounts to determine earning power
/// - Disables user staking methods (stake, withdraw, etc.)
/// - Distributes compensation proportional to governance participation metrics
abstract contract DelegateCompensationStaker is Staker {
  using SafeCast for uint256;

  /// @notice Emitted when a delegate's reward deposit is successfully initialized.
  /// @param delegate The address of the delegate for whom the reward deposit was created.
  /// @param depositId The unique identifier for the newly created deposit.
  /// @param earningPower The initial earning power assigned to the delegate based on their
  /// voting power and eligibility at the time of initialization.
  /// @dev This event is emitted once per delegate when they are first registered in the
  /// delegate compensation system.
  event DelegateCompensation__Initialized(
    address indexed delegate, DepositIdentifier indexed depositId, uint256 earningPower
  );

  /// @notice Thrown when attempting to initialize a reward deposit for a delegate who already
  /// has one.
  /// @param delegate The address of the delegate for whom initialization was attempted.
  /// @dev This error prevents duplicate deposits for the same delegate, which would corrupt
  /// the accounting system and allow unfair compensation accumulation.
  error DelegateCompensation__AlreadyInitialized(address delegate);

  /// @notice Thrown when attempting to call a method that is not supported in the delegate
  /// compensation system.
  /// @dev This error is used for methods that exist in the parent Staker contract but are
  /// intentionally disabled in this implementation as they don't apply to the delegate compensation
  /// model.
  error DelegateCompensation__MethodNotSupported();

  /// @notice Tracks whether a delegate has already been initialized for compensation.
  mapping(address delegate => bool isInitialized) public delegateInitialized;

  /// @notice Disabled in delegate compensation system. Delegates cannot change their delegatee as
  /// they are their own delegatee in this system.
  function alterDelegatee(Staker.DepositIdentifier, address) public pure override {
    revert DelegateCompensation__MethodNotSupported();
  }

  /// @notice Disabled in delegate compensation system. This contract uses the earning power
  /// calculator rather than staking to determine the earning power of a delegate.
  /// @dev Use initializeDelegateCompensation() instead to create delegate reward deposits.
  function stake(uint256, address) external pure override returns (Staker.DepositIdentifier) {
    revert DelegateCompensation__MethodNotSupported();
  }

  /// @notice Disabled in delegate compensation system. This contract uses the earning power
  /// calculator rather than staking to determine the earning power of a delegate.
  /// @dev Use initializeDelegateCompensation() instead to create delegate reward deposits.
  function stake(uint256, address, address)
    external
    pure
    override
    returns (Staker.DepositIdentifier)
  {
    revert DelegateCompensation__MethodNotSupported();
  }

  /// @notice Disabled in delegate compensation system. Delegate deposits cannot be increased as
  /// they represent compensation eligibility, not staked amounts.
  function stakeMore(Staker.DepositIdentifier, uint256) external pure override {
    revert DelegateCompensation__MethodNotSupported();
  }

  /// @notice Disabled in delegate compensation system. Delegation surrogates are not used in the
  /// delegate compensation model as delegates earn compensation directly without token delegation
  /// mechanics.
  function surrogates(address) public pure override returns (DelegationSurrogate) {
    revert DelegateCompensation__MethodNotSupported();
  }

  /// @notice Disabled in delegate compensation system. Delegate reward deposits cannot be withdrawn
  /// as they don't represent staked tokens. Delegates can only claim accumulated compensation.
  function withdraw(Staker.DepositIdentifier, uint256) public pure override {
    revert DelegateCompensation__MethodNotSupported();
  }

  /// @notice Disabled in delegate compensation system. Delegation surrogates are not used in the
  /// delegate compensation model as delegates earn compensation directly without token delegation
  /// mechanics.
  function _fetchOrDeploySurrogate(address) internal pure override returns (DelegationSurrogate) {
    revert DelegateCompensation__MethodNotSupported();
  }

  /// @notice Initializes a reward deposit for a delegate in the compensation system.
  /// @param _delegate The address of the delegate to initialize compensation for.
  /// @return The unique deposit identifier for the created delegate reward deposit.
  /// @dev This function creates a deposit entry for a delegate to start earning compensation
  /// based on their governance participation. The initial earning power is determined by
  /// querying the external oracle at the time of initialization.
  /// @dev Unlike regular staking deposit, delegate compensation deposit:
  /// - Has zero token balance (no actual staking required)
  /// - Uses the delegate as owner, claimer, and delegatee
  /// - Derives earning power from oracle-determined governance participation metrics
  /// @dev Each delegate can only be initialized once to prevent duplicate compensation tracking.
  function initializeDelegateCompensation(address _delegate)
    external
    virtual
    returns (DepositIdentifier)
  {
    if (delegateInitialized[_delegate]) revert DelegateCompensation__AlreadyInitialized(_delegate);

    _checkpointGlobalReward();

    DepositIdentifier _depositId = _useDepositId();
    uint256 _earningPower = earningPowerCalculator.getEarningPower(0, _delegate, _delegate);

    totalEarningPower += _earningPower;
    depositorTotalEarningPower[_delegate] += _earningPower;

    deposits[_depositId] = Deposit({
      balance: 0,
      delegatee: _delegate,
      earningPower: _earningPower.toUint96(),
      claimer: _delegate,
      owner: _delegate,
      rewardPerTokenCheckpoint: rewardPerTokenAccumulatedCheckpoint,
      scaledUnclaimedRewardCheckpoint: 0
    });

    delegateInitialized[_delegate] = true;

    emit DelegateCompensation__Initialized(_delegate, _depositId, _earningPower);
    return _depositId;
  }
}
