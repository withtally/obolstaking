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
    address _delegate,
    uint256 _votingPower,
    bool _eligible
  ) internal {
    deal(OBOL_TOKEN_ADDRESS, _delegate, _votingPower);
    vm.prank(_delegate);
    IVotes(OBOL_TOKEN_ADDRESS).delegate(_delegate);
    mockOracle.__setMockDelegateeEligibility(_delegate, _eligible);
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
}
