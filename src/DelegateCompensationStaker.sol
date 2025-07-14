// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Staker} from "staker/Staker.sol";
import {DelegationSurrogate} from "staker/DelegationSurrogate.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/// @title DelegateCompensationStaker
/// @author [ScopeLift](https://scopelift.co)
/// @notice Manages reward distribution for delegates based on their earning power without requiring
/// any stake.
///
/// This contract extends the base `Staker` to leverage its compensation distribution mechanics
/// while disabling all staking functionalities. Instead of users staking tokens to create
/// deposits, this system requires deposits to be initialized via the
/// `initializeDelegateCompensation`
/// method. Since deposits do not require stake the standard staking functions like `stake`,
/// `withdraw`,
/// and `stakeMore` are disabled. The other funcitonality and methods such as  `claimReward` should
/// behave
/// the same way as a standard Staker.
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

  /// @notice This method is not supported since there is no voting power to delegate.
  function alterDelegatee(DepositIdentifier, address) public pure override {
    revert DelegateCompensation__MethodNotSupported();
  }

  /// @notice This method is not supported since tokens are no longer staked.
  /// @dev Deposits can be created by calling `initializeDelegateCompensation`.
  function stake(uint256, address) external pure override returns (DepositIdentifier) {
    revert DelegateCompensation__MethodNotSupported();
  }

  /// @notice This method is not supported since tokens are no longer staked.
  /// @dev Deposits can be created by calling `initializeDelegateCompensation`.
  function stake(uint256, address, address) external pure override returns (DepositIdentifier) {
    revert DelegateCompensation__MethodNotSupported();
  }

  /// @notice This method is not supported since tokens are no longer staked.
  function stakeMore(DepositIdentifier, uint256) external pure override {
    revert DelegateCompensation__MethodNotSupported();
  }

  /// @notice This method is not supported since there is no voting power to delegate.
  function surrogates(address) public pure override returns (DelegationSurrogate) {
    revert DelegateCompensation__MethodNotSupported();
  }

  /// @notice This method is not supported since tokens are no longer staked.
  function withdraw(DepositIdentifier, uint256) public pure override {
    revert DelegateCompensation__MethodNotSupported();
  }

  /// @notice This method is not supported since there is no voting power to delegate.
  function _fetchOrDeploySurrogate(address) internal pure override returns (DelegationSurrogate) {
    revert DelegateCompensation__MethodNotSupported();
  }

  /// @notice Initializes a deposit for a delegate to earn rewards. Delegates will not earn rewards
  /// until their deposit is initialized.
  /// @param _delegate The address that owns the deposit and earns the rewards. Only one deposit
  /// will exist per delegate address.
  /// @return The unique deposit identifier for the created deposit.
  /// @dev This function creates a deposit entry for a delegate to start earning compensation
  /// based on their governance participation. The initial earning power is determined by
  /// the earning power calculator at the time of initialization.
  /// @dev Unlike regular staking deposit, delegate compensation deposit:
  /// - Has zero token balance (no actual staking required)
  /// - Uses the delegate as owner, claimer, and delegatee
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
