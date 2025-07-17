// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {MockOracleEligibilityModule} from "./mocks/MockOracleEligibilityModule.sol";
import {BinaryVotingPowerEarningPowerCalculator} from
  "../src/calculators/BinaryVotingPowerEarningPowerCalculator.sol";
import {DelegateCompensationStakerHarness} from "./harnesses/DelegateCompensationStakerHarness.sol";
import {Staker} from "staker/Staker.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PercentAssertions} from "staker-test/helpers/PercentAssertions.sol";
import {DelegateCompensationStaker} from "../src/DelegateCompensationStaker.sol";
import {DelegateCompensationStakerTest} from "./helpers/DelegateCompensationStakerTest.sol";

contract DelegateCompensationStakerIntegrationTestBase is Test, PercentAssertions {
  address constant OBOL_TOKEN_ADDRESS = 0x0B010000b7624eb9B3DfBC279673C76E9D29D5F7;
  uint48 public constant VOTING_POWER_UPDATE_INTERVAL = 3 weeks;
  uint256 public constant REWARD_AMOUNT = 165_000 * 1e18;
  uint256 public constant MAX_BUMP_TIP = 10e18;

  address owner = makeAddr("Owner");
  address public admin = makeAddr("admin");

  DelegateCompensationStakerHarness public staker;
  BinaryVotingPowerEarningPowerCalculator public calculator;
  MockOracleEligibilityModule public mockOracle;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl("mainnet_rpc_url"), 22_773_964);

    mockOracle = new MockOracleEligibilityModule();

    calculator = new BinaryVotingPowerEarningPowerCalculator(
      owner, address(mockOracle), OBOL_TOKEN_ADDRESS, VOTING_POWER_UPDATE_INTERVAL
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

  function _setDelegateeEligibilityWithVotingPower(
    address _delegatee,
    uint256 _votingPower,
    bool _eligible
  ) internal {
    // Create a unique delegator address
    address _delegator =
      makeAddr(string(abi.encodePacked("delegator_", _delegatee, "_", _votingPower)));
    _assumeValidDelegate(_delegator);
    vm.assume(_delegator != _delegatee);

    // Fund the delegator with tokens and delegate voting power to the delegatee
    deal(OBOL_TOKEN_ADDRESS, _delegator, _votingPower);
    vm.prank(_delegator);
    IVotes(OBOL_TOKEN_ADDRESS).delegate(_delegatee);

    // Configure the mock oracle with the delegatee's eligibility status
    mockOracle.__setMockDelegateeEligibility(_delegatee, _eligible);
  }

  function _boundToRealisticVotingPower(uint224 votingPower) internal pure returns (uint224) {
    return uint224(bound(votingPower, 0, type(uint96).max));
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

  function _jumpAheadByPercentOfRewardDuration(uint256 _percent) public {
    uint256 _seconds = (_percent * staker.REWARD_DURATION()) / 100;
    vm.warp(block.timestamp + _seconds);
  }

  function _calculateExpectedUnclaimedReward(
    address _delegate,
    uint256 _votingPower,
    uint256 _percentDuration
  ) internal view returns (uint256) {
    uint256 _delegateEarningPower = staker.depositorTotalEarningPower(_delegate);
    uint256 _totalEarningPower = staker.totalEarningPower();

    if (_votingPower == 0 || !mockOracle.isDelegateeEligible(_delegate)) return 0;
    if (_totalEarningPower == 0) return 0;

    return REWARD_AMOUNT * _delegateEarningPower * _percentDuration / _totalEarningPower / 100;
  }

  function assertEq(Staker.DepositIdentifier a, Staker.DepositIdentifier b) internal pure {
    assertEq(Staker.DepositIdentifier.unwrap(a), Staker.DepositIdentifier.unwrap(b));
  }
}

contract DelegateCompensationStakerIntegrationTest is
  DelegateCompensationStakerIntegrationTestBase
{
  function testForkFuzz_CorrectlyAccruesRewardsForASingleDelegate(
    address _delegate,
    uint224 _votingPower,
    uint256 _percentDuration,
    bool _eligibility
  ) public {
    _assumeValidDelegate(_delegate);
    _percentDuration = bound(_percentDuration, 1, 100);
    _votingPower = _boundToRealisticVotingPower(_votingPower);

    _setDelegateeEligibilityWithVotingPower(_delegate, _votingPower, _eligibility);

    // otherwise `getPastVotes` reverts
    vm.roll(block.number + 1);
    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    _mintTransferAndNotifyReward();
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 _expectedEarningPower = _eligibility == false ? 0 : uint256(Math.sqrt(_votingPower));
    uint256 _expectedUnclaimedReward =
      _calculateExpectedUnclaimedReward(_delegate, _votingPower, _percentDuration);

    assertEq(staker.delegateDepositId(_delegate), _depositId);
    assertEq(Staker.DepositIdentifier.unwrap(_depositId), 1);
    assertEq(staker.depositorTotalEarningPower(_delegate), _expectedEarningPower);
    assertLteWithinOnePercent(staker.unclaimedReward(_depositId), _expectedUnclaimedReward);
  }

  function testForkFuzz_CorrectlyAccruesRewardsForMultipleDelegates(
    address _delegate1,
    address _delegate2,
    uint224 _votingPower1,
    uint224 _votingPower2,
    bool _eligibility1,
    bool _eligibility2,
    uint256 _percentDuration
  ) public {
    _assumeValidDelegate(_delegate1);
    _assumeValidDelegate(_delegate2);
    vm.assume(_delegate1 != _delegate2);
    _percentDuration = bound(_percentDuration, 0, 100);

    _votingPower1 = _boundToRealisticVotingPower(_votingPower1);
    _votingPower2 = _boundToRealisticVotingPower(_votingPower2);
    _setDelegateeEligibilityWithVotingPower(_delegate1, _votingPower1, _eligibility1);
    _setDelegateeEligibilityWithVotingPower(_delegate2, _votingPower2, _eligibility2);

    // otherwise `getPastVotes` reverts
    vm.roll(block.number + 1);
    Staker.DepositIdentifier _depositId1 = staker.initializeDelegateCompensation(_delegate1);
    Staker.DepositIdentifier _depositId2 = staker.initializeDelegateCompensation(_delegate2);

    _mintTransferAndNotifyReward();
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 _expectedEarningPower1 = _eligibility1 == false ? 0 : uint256(Math.sqrt(_votingPower1));
    uint256 _expectedEarningPower2 = _eligibility2 == false ? 0 : uint256(Math.sqrt(_votingPower2));
    uint256 _expectedUnclaimedReward1 =
      _calculateExpectedUnclaimedReward(_delegate1, _votingPower1, _percentDuration);
    uint256 _expectedUnclaimedReward2 =
      _calculateExpectedUnclaimedReward(_delegate2, _votingPower2, _percentDuration);

    assertEq(staker.delegateDepositId(_delegate1), _depositId1);
    assertEq(staker.delegateDepositId(_delegate2), _depositId2);
    assertEq(Staker.DepositIdentifier.unwrap(_depositId1), 1);
    assertEq(Staker.DepositIdentifier.unwrap(_depositId2), 2);
    assertEq(staker.depositorTotalEarningPower(_delegate1), _expectedEarningPower1);
    assertEq(staker.depositorTotalEarningPower(_delegate2), _expectedEarningPower2);
    assertLteWithinOnePercent(staker.unclaimedReward(_depositId1), _expectedUnclaimedReward1);
    assertLteWithinOnePercent(staker.unclaimedReward(_depositId2), _expectedUnclaimedReward2);
  }

  function testForkFuzz_CorrectlyClaimsRewardsForASingleDelegate(
    address _delegate,
    uint224 _votingPower,
    uint256 _percentDuration,
    bool _eligibility
  ) public {
    _assumeValidDelegate(_delegate);
    _percentDuration = bound(_percentDuration, 1, 100);
    _votingPower = _boundToRealisticVotingPower(_votingPower);

    _setDelegateeEligibilityWithVotingPower(_delegate, _votingPower, _eligibility);

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

  function testForkFuzz_CorrectlyClaimsRewardsForMultipleDelegates(
    address _delegate1,
    address _delegate2,
    uint224 _votingPower1,
    uint224 _votingPower2,
    bool _eligibility1,
    bool _eligibility2,
    uint256 _percentDuration
  ) public {
    _assumeValidDelegate(_delegate1);
    _assumeValidDelegate(_delegate2);
    vm.assume(_delegate1 != _delegate2);
    _percentDuration = bound(_percentDuration, 0, 100);

    _votingPower1 = _boundToRealisticVotingPower(_votingPower1);
    _votingPower2 = _boundToRealisticVotingPower(_votingPower2);
    _setDelegateeEligibilityWithVotingPower(_delegate1, _votingPower1, _eligibility1);
    _setDelegateeEligibilityWithVotingPower(_delegate2, _votingPower2, _eligibility2);

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
    emit Staker.MaxBumpTipSet(MAX_BUMP_TIP, _newMaxBumpTip);

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

contract LastTimeRewardDistributed is DelegateCompensationStakerTest {
  function testFuzz_ReturnsTheBlockTimestampAfterARewardNotification(
    uint256 _amount,
    uint256 _durationPercent
  ) public {
    _amount = _boundToRealisticReward(_amount);
    _mintAndNotifyRewards(_amount);

    _durationPercent = bound(_durationPercent, 0, 100);
    _jumpAheadByPercentOfRewardDuration(_durationPercent);

    assertEq(staker.lastTimeRewardDistributed(), block.timestamp);
  }
}

contract UnclaimedReward is DelegateCompensationStakerTest {
  function testFuzz_CalculatesCorrectEarningsForASingleDelegate(
    uint256 _earningPower,
    uint256 _rewardAmount,
    address _delegate,
    uint256 _duration
  ) public {
    _assumeValidDelegate(_delegate);
    _earningPower = _boundToRealisticEarningPower(_earningPower);
    vm.assume(_earningPower != 0);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    calculator.setDelegateEarningPower(_delegate, _earningPower);
    _duration = bound(_duration, 0, 100);

    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    _mintAndNotifyRewards(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_duration);

    uint256 _unclaimedReward = staker.unclaimedReward(_depositId);
    assertLteWithinOnePercent(_unclaimedReward, _percentOf(_rewardAmount, _duration));
  }

  function testFuzz_CalculatesCorrectEarningsForMultipleDelegates(
    address _delegate1,
    address _delegate2,
    uint256 _earningPower1,
    uint256 _earningPower2,
    uint256 _rewardAmount,
    uint256 _duration
  ) public {
    _assumeValidDelegate(_delegate1);
    _assumeValidDelegate(_delegate2);
    vm.assume(_delegate1 != _delegate2);
    _earningPower1 = _boundToRealisticEarningPower(_earningPower1);
    _earningPower2 = _boundToRealisticEarningPower(_earningPower2);
    vm.assume(_earningPower1 != 0);
    vm.assume(_earningPower2 != 0);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    calculator.setDelegateEarningPower(_delegate1, _earningPower1);
    calculator.setDelegateEarningPower(_delegate2, _earningPower2);
    _duration = bound(_duration, 0, 100);

    Staker.DepositIdentifier _depositId1 = staker.initializeDelegateCompensation(_delegate1);
    Staker.DepositIdentifier _depositId2 = staker.initializeDelegateCompensation(_delegate2);

    _mintAndNotifyRewards(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_duration);

    uint256 _unclaimedReward1 = staker.unclaimedReward(_depositId1);
    uint256 _unclaimedReward2 = staker.unclaimedReward(_depositId2);
    uint256 _expectedReward1 =
      (_percentOf(_rewardAmount, _duration) * _earningPower1) / staker.totalEarningPower();
    uint256 _expectedReward2 =
      (_percentOf(_rewardAmount, _duration) * _earningPower2) / staker.totalEarningPower();

    assertLteWithinOnePercent(_unclaimedReward1, _expectedReward1);
    assertLteWithinOnePercent(_unclaimedReward2, _expectedReward2);
    assertLteWithinOnePercent(
      _expectedReward1 + _expectedReward2, _percentOf(_rewardAmount, _duration)
    );
  }
}

contract AlterClaimer is DelegateCompensationStakerTest {
  function testFuzz_DelegateCanAlterClaimerSuccessfully(
    uint256 _earningPower,
    address _delegate,
    address _claimer
  ) public {
    _assumeValidDelegate(_delegate);
    vm.assume(_claimer != _delegate);
    vm.assume(_claimer != address(0));
    _earningPower = _boundToRealisticEarningPower(_earningPower);
    calculator.setDelegateEarningPower(_delegate, _earningPower);

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

contract ClaimReward is DelegateCompensationStakerTest {
  function testFuzz_ASingleDelegateReceivesCompensationWhenClaiming(
    uint256 _earningPower,
    uint256 _rewardAmount,
    address _delegate,
    uint256 _duration
  ) public {
    _assumeValidDelegate(_delegate);
    _earningPower = _boundToRealisticEarningPower(_earningPower);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    calculator.setDelegateEarningPower(_delegate, _earningPower);
    _duration = bound(_duration, 0, 100);

    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    _mintAndNotifyRewards(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_duration);

    uint256 _initialBalance = rewardToken.balanceOf(_delegate);
    uint256 _unclaimedReward = staker.unclaimedReward(_depositId);

    vm.prank(_delegate);
    staker.claimReward(_depositId);

    assertEq(_initialBalance, 0);
    assertEq(rewardToken.balanceOf(_delegate), _initialBalance + _unclaimedReward);
    assertEq(staker.unclaimedReward(_depositId), 0);
  }
}

contract BumpEarningPower is DelegateCompensationStakerTest {
  function testFuzz_BumpsTheDelegateEarningPowerUp(
    uint256 _initialEarningPower,
    uint256 _newEarningPower,
    address _delegate,
    address _tipReceiver,
    uint256 _requestedTip
  ) public {
    _assumeValidDelegate(_delegate);
    vm.assume(_tipReceiver != _delegate);
    vm.assume(_tipReceiver != address(0));

    _initialEarningPower = _boundToRealisticEarningPower(_initialEarningPower);
    _newEarningPower = _boundToRealisticEarningPower(_newEarningPower);
    vm.assume(_initialEarningPower != _newEarningPower);

    calculator.setDelegateEarningPower(_delegate, _initialEarningPower);

    Staker.DepositIdentifier _depositId = staker.initializeDelegateCompensation(_delegate);

    _mintAndNotifyRewards(_boundToRealisticReward(1000e18));
    _jumpAheadByPercentOfRewardDuration(50);

    _requestedTip = bound(_requestedTip, 0, _min(MAX_BUMP_TIP, staker.unclaimedReward(_depositId)));
    calculator.setDelegateEarningPower(_delegate, _newEarningPower);
    staker.bumpEarningPower(_depositId, _tipReceiver, _requestedTip);

    (,, uint96 _finalEarningPower,,,,) = staker.deposits(_depositId);
    assertEq(_finalEarningPower, _newEarningPower);
  }
}
