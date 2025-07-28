// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {BinaryVotingPowerEarningPowerCalculator} from
  "src/calculators/BinaryVotingPowerEarningPowerCalculator.sol";
import {BinaryEligibilityOracleEarningPowerCalculator} from
  "staker/calculators/BinaryEligibilityOracleEarningPowerCalculator.sol";
import {DelegateCompensationStakerHarness} from
  "test/harnesses/DelegateCompensationStakerHarness.sol";
import {Staker} from "staker/Staker.sol";
import {IOracleEligibilityModule} from "src/interfaces/IOracleEligibilityModule.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DelegateCompensationStakerTest} from "test/helpers/DelegateCompensationStakerTest.sol";
import {PercentAssertions} from "staker-test/helpers/PercentAssertions.sol";
import {DelegateCompensationStaker} from "src/DelegateCompensationStaker.sol";

contract DelegateCompensationStakerIntegrationTestBase is Test, PercentAssertions {
  address constant OBOL_TOKEN_ADDRESS = 0x0B010000b7624eb9B3DfBC279673C76E9D29D5F7;
  uint48 public constant VOTING_POWER_UPDATE_INTERVAL = 3 weeks;
  uint256 public constant REWARD_AMOUNT = 1_650_001e18;
  uint256 public constant MAX_BUMP_TIP = 10e18;
  uint256 public constant STALE_ORACLE_WINDOW = 3 weeks;
  uint256 public constant UPDATE_ELIGIBILITY_DELAY = 3 weeks;
  uint256 public constant DELEGATE_ELIGIBILITY_THRESHOLD = 50;

  address public owner = makeAddr("owner");
  address public admin = makeAddr("admin");
  address public scoreOracle = makeAddr("scoreOracle");
  address public oraclePauseGuardian = makeAddr("oraclePauseGuardian");

  DelegateCompensationStakerHarness public staker;
  BinaryVotingPowerEarningPowerCalculator public calculator;
  IOracleEligibilityModule public oracleEligibilityModule;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl("mainnet_rpc_url"), 22_773_964);

    oracleEligibilityModule = IOracleEligibilityModule(
      address(
        new BinaryEligibilityOracleEarningPowerCalculator(
          owner,
          scoreOracle,
          STALE_ORACLE_WINDOW,
          oraclePauseGuardian,
          DELEGATE_ELIGIBILITY_THRESHOLD,
          UPDATE_ELIGIBILITY_DELAY
        )
      )
    );

    calculator = new BinaryVotingPowerEarningPowerCalculator(
      owner, address(oracleEligibilityModule), OBOL_TOKEN_ADDRESS, VOTING_POWER_UPDATE_INTERVAL
    );
    staker = new DelegateCompensationStakerHarness(
      IERC20(OBOL_TOKEN_ADDRESS), calculator, MAX_BUMP_TIP, admin
    );
  }

  function _assumeValidDelegate(address _delegate) internal view {
    vm.assume(_delegate != address(0));
    vm.assume(_delegate != address(staker));
    vm.assume(_delegate != address(calculator));
    vm.assume(_delegate != address(OBOL_TOKEN_ADDRESS));
  }

  function _setOracleAsPaused() internal {
    vm.prank(oraclePauseGuardian);
    BinaryEligibilityOracleEarningPowerCalculator(address(oracleEligibilityModule)).setOracleState(
      true
    );
  }

  // Warp until STALE_ORACLE_WINDOW has passed
  function _jumpAndSetOracleAsStale() internal {
    uint256 _staleTime = BinaryEligibilityOracleEarningPowerCalculator(
      address(oracleEligibilityModule)
    ).STALE_ORACLE_WINDOW();
    vm.warp(block.timestamp + _staleTime + 1);
  }

  function _setDelegateeEligibility(address _delegatee, bool _eligibility) internal {
    uint256 _threshold = BinaryEligibilityOracleEarningPowerCalculator(
      address(oracleEligibilityModule)
    ).delegateeEligibilityThresholdScore();
    uint256 _newScore = _eligibility ? _threshold + 1 : _threshold - 1;
    vm.prank(scoreOracle);
    BinaryEligibilityOracleEarningPowerCalculator(address(oracleEligibilityModule))
      .updateDelegateeScore(_delegatee, _newScore);
  }

  function _delegateEligibleDelegateVotingPower(address _delegatee, uint256 _votingPower) internal {
    _delegateVotingPower(_delegatee, _votingPower, true);
  }

  function _delegateIneligibleDelegateVotignPower(address _delegatee, uint256 _votingPower)
    internal
  {
    _delegateVotingPower(_delegatee, _votingPower, false);
  }

  function _delegateVotingPower(address _delegatee, uint256 _votingPower, bool _eligible) internal {
    // Create a unique delegator address
    address _delegator =
      makeAddr(string(abi.encodePacked("delegator_", _delegatee, "_", _votingPower)));
    _assumeValidDelegate(_delegator);

    // Fund the delegator with tokens and delegate voting power to the delegatee
    deal(OBOL_TOKEN_ADDRESS, _delegator, _votingPower);
    vm.prank(_delegator);
    IVotes(OBOL_TOKEN_ADDRESS).delegate(_delegatee);

    // Configure the oracle with the delegatee's eligibility status
    _setDelegateeEligibility(_delegatee, _eligible);
  }

  function _addDelegateVotingPower(address _delegator, address _delegatee, uint256 _votingPower)
    internal
  {
    // Fund the delegator with tokens and delegate voting power to the delegatee
    deal(OBOL_TOKEN_ADDRESS, _delegator, _votingPower);
    vm.prank(_delegator);
    IVotes(OBOL_TOKEN_ADDRESS).delegate(_delegatee);
  }

  function _removeDelegateVotingPower(address _delegator) internal {
    vm.prank(_delegator);
    // Remove delegation by delegating to oneself
    IVotes(OBOL_TOKEN_ADDRESS).delegate(address(0));
  }

  // Earning power is of type uint96. In delegate compensation staker, earning power is the square
  // root of voting power if the delegate is eligible or if the earning power oracle is paused or
  // stale. Therefore, the maximum safe value for the voting power is square of uint96, i.e. uint192.
  // Zero voting power is tested separately.
  function _boundToValidVotingPower(uint256 votingPower) internal pure returns (uint256) {
    return uint256(bound(votingPower, 1, type(uint192).max));
  }

  function _boundToValidBumpTip(Staker.DepositIdentifier _depositId)
    internal
    view
    returns (uint256 _requestedTip)
  {
    _requestedTip =
      bound(_requestedTip, 0, Math.min(staker.maxBumpTip(), staker.unclaimedReward(_depositId)));
  }

  function _mintTransferAndNotifyReward() internal {
    address rewardNotifier = makeAddr("rewardNotifier");

    vm.prank(staker.admin());
    staker.setRewardNotifier(rewardNotifier, true);

    deal(address(staker.REWARD_TOKEN()), rewardNotifier, REWARD_AMOUNT);

    vm.startPrank(rewardNotifier);
    IERC20(address(staker.REWARD_TOKEN())).transfer(address(staker), REWARD_AMOUNT);
    staker.notifyRewardAmount(REWARD_AMOUNT);
    vm.stopPrank();
  }

  function _jumpAheadByPercentOfRewardDuration(uint256 _percent) internal {
    uint256 _seconds = (_percent * staker.REWARD_DURATION()) / 100;
    vm.warp(block.timestamp + _seconds);
  }

  function _calculateExpectedUnclaimedReward(address _delegate, uint256 _percentDuration)
    internal
    view
    returns (uint256)
  {
    uint256 _delegateEarningPower = staker.depositorTotalEarningPower(_delegate);
    uint256 _totalEarningPower = staker.totalEarningPower();

    return (REWARD_AMOUNT * _delegateEarningPower * _percentDuration) / (_totalEarningPower * 100);
  }

  function assertEq(Staker.DepositIdentifier a, Staker.DepositIdentifier b) internal pure {
    assertEq(Staker.DepositIdentifier.unwrap(a), Staker.DepositIdentifier.unwrap(b));
  }
}

contract DelegateCompensationStakerIntegrationTest is
  DelegateCompensationStakerIntegrationTestBase
{
  function testForkFuzz_SingleDelegateAccruesRewardProportionalToVotingPower(
    address _delegate,
    uint256 _votingPower,
    uint256 _percentDuration
  ) public {
    _assumeValidDelegate(_delegate);
    _percentDuration = bound(_percentDuration, 1, 100);
    _votingPower = _boundToValidVotingPower(_votingPower);

    _delegateEligibleDelegateVotingPower(_delegate, _votingPower);

    // otherwise `getPastVotes` reverts
    vm.roll(block.number + 1);
    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    _mintTransferAndNotifyReward();
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 _expectedEarningPower = uint256(Math.sqrt(_votingPower));
    uint256 _expectedUnclaimedReward =
      _calculateExpectedUnclaimedReward(_delegate, _percentDuration);

    assertEq(staker.delegateDepositId(_delegate), _depositId);
    assertEq(Staker.DepositIdentifier.unwrap(_depositId), 1);
    assertEq(staker.depositorTotalEarningPower(_delegate), _expectedEarningPower);
    assertLteWithinOnePercent(staker.unclaimedReward(_depositId), _expectedUnclaimedReward);
  }

  function testForkFuzz_SingleDelegateWithoutVotingPowerDoesNotAccrueReward(
    address _delegate,
    uint256 _percentDuration
  ) public {
    _assumeValidDelegate(_delegate);
    _percentDuration = bound(_percentDuration, 1, 100);

    _delegateEligibleDelegateVotingPower(_delegate, 0);

    // otherwise `getPastVotes` reverts
    vm.roll(block.number + 1);
    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    _mintTransferAndNotifyReward();
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    assertEq(staker.delegateDepositId(_delegate), _depositId);
    assertEq(Staker.DepositIdentifier.unwrap(_depositId), 1);
    assertEq(staker.depositorTotalEarningPower(_delegate), 0);
    assertEq(staker.unclaimedReward(_depositId), 0);
  }

  function testForkFuzz_SingleIneligibleDelegateDoesNotAccrueReward(
    address _delegate,
    uint256 _votingPower,
    uint256 _percentDuration
  ) public {
    _assumeValidDelegate(_delegate);
    _percentDuration = bound(_percentDuration, 1, 100);
    _votingPower = _boundToValidVotingPower(_votingPower);

    _delegateIneligibleDelegateVotignPower(_delegate, _votingPower);

    // otherwise `getPastVotes` reverts
    vm.roll(block.number + 1);
    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    _mintTransferAndNotifyReward();
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    assertEq(staker.delegateDepositId(_delegate), _depositId);
    assertEq(Staker.DepositIdentifier.unwrap(_depositId), 1);
    assertEq(staker.depositorTotalEarningPower(_delegate), 0);
    assertEq(staker.unclaimedReward(_depositId), 0);
  }

  function testForkFuzz_MultipleDelegatesAccrueRewardsProportionalToVotingPower(
    address _delegate1,
    address _delegate2,
    uint256 _votingPower1,
    uint256 _votingPower2,
    uint256 _percentDuration
  ) public {
    _assumeValidDelegate(_delegate1);
    _assumeValidDelegate(_delegate2);
    vm.assume(_delegate1 != _delegate2);
    _percentDuration = bound(_percentDuration, 1, 100);

    _votingPower1 = _boundToValidVotingPower(_votingPower1);
    _votingPower2 = _boundToValidVotingPower(_votingPower2);
    _delegateEligibleDelegateVotingPower(_delegate1, _votingPower1);
    _delegateEligibleDelegateVotingPower(_delegate2, _votingPower2);

    // otherwise `getPastVotes` reverts
    vm.roll(block.number + 1);
    Staker.DepositIdentifier _depositId1 = staker.initializeDelegateCompensation(_delegate1);
    Staker.DepositIdentifier _depositId2 = staker.initializeDelegateCompensation(_delegate2);

    _mintTransferAndNotifyReward();
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 _expectedEarningPower1 = uint256(Math.sqrt(_votingPower1));
    uint256 _expectedEarningPower2 = uint256(Math.sqrt(_votingPower2));
    uint256 _expectedUnclaimedReward1 =
      _calculateExpectedUnclaimedReward(_delegate1, _percentDuration);
    uint256 _expectedUnclaimedReward2 =
      _calculateExpectedUnclaimedReward(_delegate2, _percentDuration);

    assertEq(staker.delegateDepositId(_delegate1), _depositId1);
    assertEq(staker.delegateDepositId(_delegate2), _depositId2);
    assertEq(Staker.DepositIdentifier.unwrap(_depositId1), 1);
    assertEq(Staker.DepositIdentifier.unwrap(_depositId2), 2);
    assertEq(staker.depositorTotalEarningPower(_delegate1), _expectedEarningPower1);
    assertEq(staker.depositorTotalEarningPower(_delegate2), _expectedEarningPower2);
    assertLteWithinOnePercent(staker.unclaimedReward(_depositId1), _expectedUnclaimedReward1);
    assertLteWithinOnePercent(staker.unclaimedReward(_depositId2), _expectedUnclaimedReward2);
  }

  function testForkFuzz_MultipleDelegatesWithoutVotingPowerDoNotAccrueReward(
    address _delegate1,
    address _delegate2,
    uint256 _percentDuration
  ) public {
    _assumeValidDelegate(_delegate1);
    _assumeValidDelegate(_delegate2);
    vm.assume(_delegate1 != _delegate2);
    _percentDuration = bound(_percentDuration, 1, 100);

    _delegateEligibleDelegateVotingPower(_delegate1, 0);
    _delegateEligibleDelegateVotingPower(_delegate2, 0);

    // otherwise `getPastVotes` reverts
    vm.roll(block.number + 1);
    Staker.DepositIdentifier _depositId1 = staker.initializeDelegateCompensation(_delegate1);
    Staker.DepositIdentifier _depositId2 = staker.initializeDelegateCompensation(_delegate2);

    _mintTransferAndNotifyReward();
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    assertEq(staker.delegateDepositId(_delegate1), _depositId1);
    assertEq(staker.delegateDepositId(_delegate2), _depositId2);
    assertEq(Staker.DepositIdentifier.unwrap(_depositId1), 1);
    assertEq(Staker.DepositIdentifier.unwrap(_depositId2), 2);
    assertEq(staker.depositorTotalEarningPower(_delegate1), 0);
    assertEq(staker.depositorTotalEarningPower(_delegate2), 0);
    assertEq(staker.unclaimedReward(_depositId1), 0);
    assertEq(staker.unclaimedReward(_depositId2), 0);
  }

  function testForkFuzz_MultipleIneligibleDelegatesDoNotAccrueReward(
    address _delegate1,
    address _delegate2,
    uint256 _votingPower1,
    uint256 _votingPower2,
    uint256 _percentDuration
  ) public {
    _assumeValidDelegate(_delegate1);
    _assumeValidDelegate(_delegate2);
    vm.assume(_delegate1 != _delegate2);
    _percentDuration = bound(_percentDuration, 1, 100);

    _votingPower1 = _boundToValidVotingPower(_votingPower1);
    _votingPower2 = _boundToValidVotingPower(_votingPower2);
    _delegateIneligibleDelegateVotignPower(_delegate1, _votingPower1);
    _delegateIneligibleDelegateVotignPower(_delegate2, _votingPower2);

    // otherwise `getPastVotes` reverts
    vm.roll(block.number + 1);
    Staker.DepositIdentifier _depositId1 = staker.initializeDelegateCompensation(_delegate1);
    Staker.DepositIdentifier _depositId2 = staker.initializeDelegateCompensation(_delegate2);

    _mintTransferAndNotifyReward();
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    assertEq(staker.delegateDepositId(_delegate1), _depositId1);
    assertEq(staker.delegateDepositId(_delegate2), _depositId2);
    assertEq(Staker.DepositIdentifier.unwrap(_depositId1), 1);
    assertEq(Staker.DepositIdentifier.unwrap(_depositId2), 2);
    assertEq(staker.depositorTotalEarningPower(_delegate1), 0);
    assertEq(staker.depositorTotalEarningPower(_delegate2), 0);
    assertEq(staker.unclaimedReward(_depositId1), 0);
    assertEq(staker.unclaimedReward(_depositId2), 0);
  }

  function testForkFuzz_SingleDelegateInitializedDuringActiveRewardPeriodAccruesRewardCorrectly(
    address _delegate,
    uint256 _votingPower,
    uint256 _percentDuration
  ) public {
    _assumeValidDelegate(_delegate);
    _percentDuration = bound(_percentDuration, 1, 50);
    _votingPower = _boundToValidVotingPower(_votingPower);

    _delegateEligibleDelegateVotingPower(_delegate, _votingPower);

    _mintTransferAndNotifyReward();
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    // otherwise `getPastVotes` reverts
    vm.roll(block.number + 1);
    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 _expectedUnclaimedReward =
      _calculateExpectedUnclaimedReward(_delegate, _percentDuration);

    assertLteWithinOnePercent(staker.unclaimedReward(_depositId), _expectedUnclaimedReward);
  }

  function testForkFuzz_DelegateAccruesRewardWhenOracleIsPaused(
    address _delegate,
    uint256 _votingPower,
    uint256 _percentDuration
  ) public {
    _assumeValidDelegate(_delegate);
    _percentDuration = bound(_percentDuration, 1, 100);
    _votingPower = _boundToValidVotingPower(_votingPower);

    _delegateEligibleDelegateVotingPower(_delegate, _votingPower);

    // otherwise `getPastVotes` reverts
    vm.roll(block.number + 1);
    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    _mintTransferAndNotifyReward();

    // Pause Oracle
    _setOracleAsPaused();
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 _initialBalance = staker.REWARD_TOKEN().balanceOf(_delegate);
    uint256 _expectedUnclaimedReward =
      _calculateExpectedUnclaimedReward(_delegate, _percentDuration);

    // earning power updated inside claimReward call
    vm.prank(_delegate);
    staker.claimReward(_depositId);

    assertEq(_initialBalance, 0);
    assertLteWithinOnePercent(
      staker.REWARD_TOKEN().balanceOf(_delegate), _initialBalance + _expectedUnclaimedReward
    );
    assertEq(staker.unclaimedReward(_depositId), 0);
  }

  function testForkFuzz_DelegateAccruesRewardWhenOracleIsStale(
    address _delegate,
    uint256 _votingPower,
    uint256 _percentDuration
  ) public {
    _assumeValidDelegate(_delegate);
    _percentDuration = bound(_percentDuration, 1, 100);
    _votingPower = _boundToValidVotingPower(_votingPower);

    _delegateEligibleDelegateVotingPower(_delegate, _votingPower);

    // otherwise `getPastVotes` reverts
    vm.roll(block.number + 1);
    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    _mintTransferAndNotifyReward();
    // Pause Oracle
    _jumpAndSetOracleAsStale();
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    // Calculate total elapsed time in seconds
    uint256 _staleTime = BinaryEligibilityOracleEarningPowerCalculator(
      address(oracleEligibilityModule)
    ).STALE_ORACLE_WINDOW() + 1;
    uint256 _initialElapsedTime = (_percentDuration * staker.REWARD_DURATION()) / 100;
    uint256 _totalElapsedTime = _initialElapsedTime + _staleTime;

    // Cap elapsted time at reward duration
    uint256 _cappedElapsedTime = Math.min(_totalElapsedTime, staker.REWARD_DURATION());

    // Calculate expected reward using time-based formula (matching contract logic)
    uint256 _delegateEarningPower = staker.depositorTotalEarningPower(_delegate);
    uint256 _totalEarningPower = staker.totalEarningPower();

    uint256 _expectedUnclaimedReward = REWARD_AMOUNT * _delegateEarningPower * _cappedElapsedTime
      / _totalEarningPower / staker.REWARD_DURATION();

    // earning power updated inside claimReward call
    vm.prank(_delegate);
    staker.claimReward(_depositId);

    assertLteWithinOnePercent(staker.REWARD_TOKEN().balanceOf(_delegate), _expectedUnclaimedReward);
    assertEq(staker.unclaimedReward(_depositId), 0);
  }

  function testForkFuzz_SingleDelegateClaimsRewardProportionalToVotingPower(
    address _delegate,
    uint256 _votingPower,
    uint256 _percentDuration,
    bool _eligibility
  ) public {
    _assumeValidDelegate(_delegate);
    _percentDuration = bound(_percentDuration, 1, 100);
    _votingPower = _boundToValidVotingPower(_votingPower);

    _delegateVotingPower(_delegate, _votingPower, _eligibility);

    // otherwise `getPastVotes` reverts
    vm.roll(block.number + 1);
    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    _mintTransferAndNotifyReward();
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 _initialBalance = staker.REWARD_TOKEN().balanceOf(_delegate);
    uint256 _unclaimedReward = staker.unclaimedReward(_depositId);

    vm.prank(_delegate);
    staker.claimReward(_depositId);

    assertEq(_initialBalance, 0);
    assertEq(staker.REWARD_TOKEN().balanceOf(_delegate), _initialBalance + _unclaimedReward);
    assertEq(staker.unclaimedReward(_depositId), 0);
  }

  function testForkFuzz_MultipleDelegatesClaimRewardsProportionalToVotingPower(
    address _delegate1,
    address _delegate2,
    uint256 _votingPower1,
    uint256 _votingPower2,
    bool _eligibility1,
    bool _eligibility2,
    uint256 _percentDuration
  ) public {
    _assumeValidDelegate(_delegate1);
    _assumeValidDelegate(_delegate2);
    vm.assume(_delegate1 != _delegate2);
    _percentDuration = bound(_percentDuration, 1, 100);

    _votingPower1 = _boundToValidVotingPower(_votingPower1);
    _votingPower2 = _boundToValidVotingPower(_votingPower2);
    _delegateVotingPower(_delegate1, _votingPower1, _eligibility1);
    _delegateVotingPower(_delegate2, _votingPower2, _eligibility2);

    // otherwise `getPastVotes` reverts
    vm.roll(block.number + 1);
    Staker.DepositIdentifier _depositId1 = staker.initializeDelegateCompensation(_delegate1);
    Staker.DepositIdentifier _depositId2 = staker.initializeDelegateCompensation(_delegate2);

    _mintTransferAndNotifyReward();
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 _initialBalance1 = staker.REWARD_TOKEN().balanceOf(_delegate1);
    uint256 _initialBalance2 = staker.REWARD_TOKEN().balanceOf(_delegate2);
    uint256 _unclaimedReward1 = staker.unclaimedReward(_depositId1);
    uint256 _unclaimedReward2 = staker.unclaimedReward(_depositId2);

    vm.prank(_delegate1);
    staker.claimReward(_depositId1);

    vm.prank(_delegate2);
    staker.claimReward(_depositId2);

    assertEq(_initialBalance1, 0);
    assertEq(_initialBalance2, 0);
    assertEq(staker.REWARD_TOKEN().balanceOf(_delegate1), _initialBalance1 + _unclaimedReward1);
    assertEq(staker.REWARD_TOKEN().balanceOf(_delegate2), _initialBalance2 + _unclaimedReward2);
    assertEq(staker.unclaimedReward(_depositId1), 0);
    assertEq(staker.unclaimedReward(_depositId2), 0);
  }
}

contract SetAdmin is DelegateCompensationStakerTest {
  function testFuzz_AdminCanSetNewAdmin(address _newAdmin) public {
    vm.assume(_newAdmin != address(0));

    vm.expectEmit();
    emit Staker.AdminSet(admin, _newAdmin);

    vm.prank(admin);
    staker.setAdmin(_newAdmin);

    assertEq(staker.admin(), _newAdmin);
  }
}

contract SetEarningPowerCalculator is DelegateCompensationStakerTest {
  function testFuzz_AdminCanSetEarningPowerCalculator(address _newCalculator) public {
    vm.assume(_newCalculator != address(0));

    vm.expectEmit();
    emit Staker.EarningPowerCalculatorSet(address(calculator), _newCalculator);

    vm.prank(admin);
    staker.setEarningPowerCalculator(_newCalculator);

    assertEq(address(staker.earningPowerCalculator()), _newCalculator);
  }
}

contract SetMaxBumpTip is DelegateCompensationStakerTest {
  function testFuzz_AdminCanSetMaxBumpTip(uint256 _newMaxBumpTip) public {
    vm.expectEmit();
    emit Staker.MaxBumpTipSet(staker.maxBumpTip(), _newMaxBumpTip);

    vm.prank(admin);
    staker.setMaxBumpTip(_newMaxBumpTip);

    assertEq(staker.maxBumpTip(), _newMaxBumpTip);
  }
}

contract SetRewardNotifier is DelegateCompensationStakerTest {
  function testFuzz_AdminCanSetRewardNotifier(address _notifier, bool _isEnabled) public {
    vm.expectEmit();
    emit Staker.RewardNotifierSet(_notifier, _isEnabled);

    vm.prank(admin);
    staker.setRewardNotifier(_notifier, _isEnabled);

    assertEq(staker.isRewardNotifier(_notifier), _isEnabled);
  }
}

contract SetClaimFeeParameters is DelegateCompensationStakerTest {
  function testFuzz_AdminCanSetClaimFeeParameters(
    DelegateCompensationStaker.ClaimFeeParameters memory _newParams
  ) public {
    vm.assume(_newParams.feeCollector != address(0));
    _newParams.feeAmount = uint96(bound(_newParams.feeAmount, 0, staker.MAX_CLAIM_FEE()));

    (uint96 _initialFeeAmount, address _initialFeeCollector) = staker.claimFeeParameters();

    vm.expectEmit();
    emit Staker.ClaimFeeParametersSet(
      _initialFeeAmount, _newParams.feeAmount, _initialFeeCollector, _newParams.feeCollector
    );

    vm.prank(admin);
    staker.setClaimFeeParameters(_newParams);

    (uint96 _newFeeAmount, address _newFeeCollector) = staker.claimFeeParameters();
    assertEq(_newFeeAmount, _newParams.feeAmount);
    assertEq(_newFeeCollector, _newParams.feeCollector);
  }
}

contract UnclaimedReward is DelegateCompensationStakerIntegrationTestBase {
  function testFuzz_CalculatesCorrectEarningsForASingleDelegate(
    address _delegate,
    uint256 _votingPower,
    uint256 _percentDuration
  ) public {
    _assumeValidDelegate(_delegate);
    _percentDuration = bound(_percentDuration, 1, 100);
    _votingPower = _boundToValidVotingPower(_votingPower);

    _delegateEligibleDelegateVotingPower(_delegate, _votingPower);

    // otherwise `getPastVotes` reverts
    vm.roll(block.number + 1);
    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    _mintTransferAndNotifyReward();
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 _unclaimedReward = staker.unclaimedReward(_depositId);
    uint256 _expectedReward = _calculateExpectedUnclaimedReward(_delegate, _percentDuration);
    assertLteWithinOnePercent(_unclaimedReward, _expectedReward);
  }

  function testFuzz_CalculatesCorrectEarningsForMultipleDelegates(
    address _delegate1,
    address _delegate2,
    uint256 _votingPower1,
    uint256 _votingPower2,
    uint256 _percentDuration
  ) public {
    _assumeValidDelegate(_delegate1);
    _assumeValidDelegate(_delegate2);
    vm.assume(_delegate1 != _delegate2);
    _votingPower1 = _boundToValidVotingPower(_votingPower1);
    _votingPower2 = _boundToValidVotingPower(_votingPower2);
    _delegateEligibleDelegateVotingPower(_delegate1, _votingPower1);
    _delegateEligibleDelegateVotingPower(_delegate2, _votingPower2);
    _percentDuration = bound(_percentDuration, 1, 100);

    // otherwise `getPastVotes` reverts
    vm.roll(block.number + 1);
    Staker.DepositIdentifier _depositId1 = staker.initializeDelegateCompensation(_delegate1);
    Staker.DepositIdentifier _depositId2 = staker.initializeDelegateCompensation(_delegate2);

    _mintTransferAndNotifyReward();
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 _unclaimedReward1 = staker.unclaimedReward(_depositId1);
    uint256 _unclaimedReward2 = staker.unclaimedReward(_depositId2);
    uint256 _expectedReward1 = _calculateExpectedUnclaimedReward(_delegate1, _percentDuration);
    uint256 _expectedReward2 = _calculateExpectedUnclaimedReward(_delegate2, _percentDuration);

    assertLteWithinOnePercent(_unclaimedReward1, _expectedReward1);
    assertLteWithinOnePercent(_unclaimedReward2, _expectedReward2);
    assertLteWithinOnePercent(
      _expectedReward1 + _expectedReward2, _percentOf(REWARD_AMOUNT, _percentDuration)
    );
  }
}

contract AlterClaimer is DelegateCompensationStakerIntegrationTestBase {
  function testFuzz_DelegateCanAlterClaimerSuccessfully(
    uint256 _votingPower,
    address _delegate,
    address _claimer
  ) public {
    _assumeValidDelegate(_delegate);
    vm.assume(_claimer != _delegate);
    vm.assume(_claimer != address(0));
    _votingPower = _boundToValidVotingPower(_votingPower);
    _delegateEligibleDelegateVotingPower(_delegate, _votingPower);

    // otherwise `getPastVotes` reverts
    vm.roll(block.number + 1);
    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    (,,, address _initialDelegatee, address _initialClaimer,,) = staker.deposits(_depositId);
    assertEq(_initialClaimer, _delegate);
    assertEq(_initialDelegatee, _delegate);

    uint256 _currentEarningPower = calculator.getEarningPower(0, _delegate, _delegate);
    vm.expectEmit(true, true, true, true);
    emit Staker.ClaimerAltered(_depositId, _delegate, _claimer, _currentEarningPower);

    vm.prank(_delegate);
    staker.alterClaimer(_depositId, _claimer);

    (,,,, address _newClaimer,,) = staker.deposits(_depositId);
    assertEq(_claimer, _newClaimer);
  }
}

contract ClaimReward is DelegateCompensationStakerIntegrationTestBase {
  function testFuzz_ASingleDelegateReceivesCompensationWhenClaiming(
    uint256 _votingPower,
    address _delegate,
    uint256 _percentDuration
  ) public {
    _assumeValidDelegate(_delegate);
    _votingPower = _boundToValidVotingPower(_votingPower);
    _delegateEligibleDelegateVotingPower(_delegate, _votingPower);
    _percentDuration = bound(_percentDuration, 1, 100);

    // otherwise `getPastVotes` reverts
    vm.roll(block.number + 1);
    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    _mintTransferAndNotifyReward();
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 _initialBalance = staker.REWARD_TOKEN().balanceOf(_delegate);
    uint256 _unclaimedReward = staker.unclaimedReward(_depositId);

    vm.prank(_delegate);
    staker.claimReward(_depositId);

    assertEq(_initialBalance, 0);
    assertEq(staker.REWARD_TOKEN().balanceOf(_delegate), _initialBalance + _unclaimedReward);
    assertEq(staker.unclaimedReward(_depositId), 0);
  }
}

contract BumpEarningPower is DelegateCompensationStakerIntegrationTestBase {
  function testFuzz_BumpingDelegateEarningPowerChangesDelegateEarningPower(
    uint256 _initialVotingPower,
    uint256 _newVotingPower,
    address _delegator1,
    address _delegator2,
    address _delegatee,
    address _tipReceiver,
    uint256 _requestedTip,
    uint256 _percentDuration
  ) public {
    _assumeValidDelegate(_delegator1);
    _assumeValidDelegate(_delegator2);
    _assumeValidDelegate(_delegatee);
    vm.assume(_delegator1 != _delegator2);
    vm.assume(_delegatee != _delegator1);
    vm.assume(_delegatee != _delegator2);
    vm.assume(_tipReceiver != _delegator1);
    vm.assume(_tipReceiver != _delegator2);
    vm.assume(_tipReceiver != _delegatee);
    vm.assume(_tipReceiver != address(0));

    _initialVotingPower = _boundToValidVotingPower(_initialVotingPower);
    _newVotingPower = _boundToValidVotingPower(_newVotingPower);
    vm.assume(Math.sqrt(_initialVotingPower) != Math.sqrt(_newVotingPower));

    // Set initial voting power
    _addDelegateVotingPower(_delegator1, _delegatee, _initialVotingPower);
    _setDelegateeEligibility(_delegatee, true);

    // otherwise `getPastVotes` reverts
    vm.roll(block.number + 1);
    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegatee);

    // Reset delegate voting power
    _removeDelegateVotingPower(_delegator1);
    _addDelegateVotingPower(_delegator2, _delegatee, _newVotingPower);
    vm.roll(block.number + calculator.votingPowerUpdateInterval());

    _mintTransferAndNotifyReward();

    // lower bound set to 1 to prevent bumpEarningPower revert on insufficient unclaimedRewards
    _percentDuration = bound(_percentDuration, 1, 100);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 _expectedNewEarningPower = uint256(Math.sqrt(_newVotingPower));
    _requestedTip = _boundToValidBumpTip(_depositId);

    staker.bumpEarningPower(_depositId, _tipReceiver, _requestedTip);

    (,, uint96 _newEarningPower,,,,) = staker.deposits(_depositId);
    assertEq(_newEarningPower, _expectedNewEarningPower);
  }

  function testFuzz_BumpingDelegateEarningPowerChangesAccrualOfRewards(
    uint256 _initialVotingPower,
    uint256 _newVotingPower,
    address _delegator1,
    address _delegator2,
    address _delegatee,
    address _tipReceiver,
    uint256 _requestedTip,
    uint256 _percentDuration
  ) public {
    _assumeValidDelegate(_delegator1);
    _assumeValidDelegate(_delegator2);
    _assumeValidDelegate(_delegatee);
    vm.assume(_delegator1 != _delegator2);
    vm.assume(_delegatee != _delegator1);
    vm.assume(_delegatee != _delegator2);
    vm.assume(_tipReceiver != _delegator1);
    vm.assume(_tipReceiver != _delegator2);
    vm.assume(_tipReceiver != _delegatee);
    vm.assume(_tipReceiver != address(0));

    _initialVotingPower = _boundToValidVotingPower(_initialVotingPower);
    _newVotingPower = _boundToValidVotingPower(_newVotingPower);
    vm.assume(Math.sqrt(_initialVotingPower) != Math.sqrt(_newVotingPower));

    // Set initial voting power
    _addDelegateVotingPower(_delegator1, _delegatee, _initialVotingPower);
    _setDelegateeEligibility(_delegatee, true);

    // otherwise `getPastVotes` reverts
    vm.roll(block.number + 1);
    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegatee);

    // Reset delegate voting power
    _removeDelegateVotingPower(_delegator1);
    _addDelegateVotingPower(_delegator2, _delegatee, _newVotingPower);
    vm.roll(block.number + calculator.votingPowerUpdateInterval());

    _mintTransferAndNotifyReward();

    // lower bound set to 1 to prevent bumpEarningPower revert on insufficient unclaimedRewards
    _percentDuration = bound(_percentDuration, 1, 50);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);
    uint256 _expectedUnclaimedReward1 =
      _calculateExpectedUnclaimedReward(_delegatee, _percentDuration);

    _requestedTip = _boundToValidBumpTip(_depositId);
    staker.bumpEarningPower(_depositId, _tipReceiver, _requestedTip);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);
    uint256 _expectedUnclaimedReward2 =
      _calculateExpectedUnclaimedReward(_delegatee, _percentDuration);

    assertLteWithinOneUnit(
      staker.unclaimedReward(_depositId), _expectedUnclaimedReward1 + _expectedUnclaimedReward2
    );
  }
}
