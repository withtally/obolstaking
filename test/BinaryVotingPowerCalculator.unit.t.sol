// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {MockVotingPowerToken} from "test/mocks/MockVotingPowerToken.sol";

import {MockEligibilityModule} from "test/mocks/MockEligibilityModule.sol";
import {BinaryVotingPowerCalculator} from "src/calculators/BinaryVotingPowerCalculator.sol";

contract BinaryVotingPowerCalculatorTest is Test {
  BinaryVotingPowerCalculator public calculator;
  MockEligibilityModule public mockEligibilityModule;
  MockVotingPowerToken public mockVotingPowerToken;
  address public owner = makeAddr("owner");
  uint48 public votingPowerUpdateInterval = 100;

  function setUp() public {
    mockEligibilityModule = new MockEligibilityModule();
    mockVotingPowerToken = new MockVotingPowerToken();
    calculator = new BinaryVotingPowerCalculator(
      owner,
      address(mockEligibilityModule),
      address(mockVotingPowerToken),
      votingPowerUpdateInterval
    );
  }

  function _assumeSafeOwner(address _owner) internal pure {
    vm.assume(_owner != address(0));
  }

  function _assumeSafeVotingPowerToken(address _votingPowerToken) internal pure {
    vm.assume(_votingPowerToken != address(0));
  }

  function _assumeSafeVotingPowerUpdateInterval(uint48 _votingPowerUpdateInterval) internal pure {
    vm.assume(_votingPowerUpdateInterval != 0);
  }

  function _assumeSafeEligibilityModule(address _eligibilityModule) internal pure {
    vm.assume(_eligibilityModule != address(0));
  }

  function _assumeSafeInitialParameters(
    address _owner,
    address _votingPowerToken,
    uint48 _votingPowerUpdateInterval,
    address _eligibilityModule
  ) internal pure {
    _assumeSafeOwner(_owner);
    _assumeSafeVotingPowerToken(_votingPowerToken);
    _assumeSafeVotingPowerUpdateInterval(_votingPowerUpdateInterval);
    _assumeSafeEligibilityModule(_eligibilityModule);
  }

  function _assumeSafeDelegate(address _delegate) internal pure {
    vm.assume(_delegate != address(0));
  }

  function _setOracleAsAvailable() internal {
    mockEligibilityModule.__setMockIsOraclePaused(false);
    mockEligibilityModule.__setMockIsOracleStale(false);
  }

  function _setOracleAsUnavailableAsOraclePaused() internal {
    mockEligibilityModule.__setMockIsOraclePaused(true);
  }

  function _setOracleAsUnavailableAsOracleStale() internal {
    mockEligibilityModule.__setMockIsOracleStale(true);
  }

  function _setVotingPowerForDelegate(address _delegate, uint256 _votingPower) internal {
    mockVotingPowerToken.__setMockBalanceOf(_delegate, _votingPower);
  }

  function _setDelegateeAsEligibleWithVotingPower(address _delegate, uint256 _votingPower) internal {
    _assumeSafeDelegate(_delegate);
    mockEligibilityModule.__setMockDelegateeEligibility(_delegate, true);

    _setVotingPowerForDelegate(_delegate, _votingPower);
  }

  function _setDelegateeAsNotEligibleWithVotingPower(address _delegate, uint256 _votingPower)
    internal
  {
    _assumeSafeDelegate(_delegate);
    mockEligibilityModule.__setMockDelegateeEligibility(_delegate, false);

    _setVotingPowerForDelegate(_delegate, _votingPower);
  }
}

contract Constructor is BinaryVotingPowerCalculatorTest {
  function testFuzz_SetsInitialParameters(
    address _owner,
    address _votingPowerToken,
    uint48 _votingPowerUpdateInterval,
    address _eligibilityModule
  ) public {
    _assumeSafeInitialParameters(
      _owner, _votingPowerToken, _votingPowerUpdateInterval, _eligibilityModule
    );

    BinaryVotingPowerCalculator _calculator = new BinaryVotingPowerCalculator(
      _owner, _eligibilityModule, _votingPowerToken, _votingPowerUpdateInterval
    );

    assertEq(_calculator.owner(), _owner);
    assertEq(_calculator.VOTING_POWER_TOKEN(), _votingPowerToken);
    assertEq(_calculator.votingPowerUpdateInterval(), _votingPowerUpdateInterval);
    assertEq(address(_calculator.eligibilityModule()), _eligibilityModule);
    assertEq(_calculator.SNAPSHOT_START_BLOCK(), uint48(block.number));
  }

  function testFuzz_EmitsEligibilityModuleSetEvent(
    address _owner,
    address _votingPowerToken,
    uint48 _votingPowerUpdateInterval,
    address _eligibilityModule
  ) public {
    _assumeSafeInitialParameters(
      _owner, _votingPowerToken, _votingPowerUpdateInterval, _eligibilityModule
    );

    vm.expectEmit();
    emit BinaryVotingPowerCalculator.EligibilityModuleSet(address(0), _eligibilityModule);
    new BinaryVotingPowerCalculator(
      _owner, _eligibilityModule, _votingPowerToken, _votingPowerUpdateInterval
    );
  }

  function testFuzz_EmitsVotingPowerUpdateIntervalSetEvent(
    address _owner,
    address _votingPowerToken,
    uint48 _votingPowerUpdateInterval,
    address _eligibilityModule
  ) public {
    _assumeSafeInitialParameters(
      _owner, _votingPowerToken, _votingPowerUpdateInterval, _eligibilityModule
    );

    vm.expectEmit();
    emit BinaryVotingPowerCalculator.VotingPowerUpdateIntervalSet(0, _votingPowerUpdateInterval);
    new BinaryVotingPowerCalculator(
      _owner, _eligibilityModule, _votingPowerToken, _votingPowerUpdateInterval
    );
  }

  function testFuzz_RevertIf_OwnerIsZeroAddress(
    address _votingPowerToken,
    uint48 _votingPowerUpdateInterval,
    address _eligibilityModule
  ) public {
    _assumeSafeVotingPowerToken(_votingPowerToken);
    _assumeSafeVotingPowerUpdateInterval(_votingPowerUpdateInterval);
    _assumeSafeEligibilityModule(_eligibilityModule);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
    new BinaryVotingPowerCalculator(
      address(0), _eligibilityModule, _votingPowerToken, _votingPowerUpdateInterval
    );
  }

  function testFuzz_RevertIf_EligibilityModuleIsZeroAddress(
    address _owner,
    address _votingPowerToken,
    uint48 _votingPowerUpdateInterval
  ) public {
    _assumeSafeOwner(_owner);
    _assumeSafeVotingPowerToken(_votingPowerToken);
    _assumeSafeVotingPowerUpdateInterval(_votingPowerUpdateInterval);

    vm.expectRevert(
      BinaryVotingPowerCalculator.BinaryVotingPowerCalculator__InvalidAddress.selector
    );
    new BinaryVotingPowerCalculator(
      _owner, address(0), _votingPowerToken, _votingPowerUpdateInterval
    );
  }

  function testFuzz_RevertIf_VotingPowerTokenIsZeroAddress(
    address _owner,
    uint48 _votingPowerUpdateInterval,
    address _eligibilityModule
  ) public {
    _assumeSafeOwner(_owner);
    _assumeSafeVotingPowerUpdateInterval(_votingPowerUpdateInterval);
    _assumeSafeEligibilityModule(_eligibilityModule);

    vm.expectRevert(
      BinaryVotingPowerCalculator.BinaryVotingPowerCalculator__InvalidAddress.selector
    );
    new BinaryVotingPowerCalculator(
      _owner, _eligibilityModule, address(0), _votingPowerUpdateInterval
    );
  }

  function testFuzz_RevertIf_VotingPowerUpdateIntervalIsZero(
    address _owner,
    address _votingPowerToken,
    address _eligibilityModule
  ) public {
    _assumeSafeOwner(_owner);
    _assumeSafeVotingPowerToken(_votingPowerToken);
    _assumeSafeEligibilityModule(_eligibilityModule);

    vm.expectRevert(
      BinaryVotingPowerCalculator
        .BinaryVotingPowerCalculator__InvalidVotingPowerUpdateInterval
        .selector
    );
    new BinaryVotingPowerCalculator(_owner, _eligibilityModule, _votingPowerToken, 0);
  }
}

contract GetEarningPower is BinaryVotingPowerCalculatorTest {
  // Oracle is available && delegate IS eligible → return sqrt(votingPower)
  function testFuzz_AvailableOracleAndEligibleDelegateHasEarningPower(
    address _delegate,
    uint256 _votingPower,
    uint256 _unusedParam1,
    address _unusedParam2
  ) public {
    _setOracleAsAvailable();
    _setDelegateeAsEligibleWithVotingPower(_delegate, _votingPower);

    uint256 _expectedVotingPower = uint256(Math.sqrt(_votingPower));

    assertEq(
      calculator.getEarningPower(_unusedParam1, _delegate, _unusedParam2), _expectedVotingPower
    );
  }

  // Oracle is paused && delegate IS eligible → return sqrt(votingPower)
  function testFuzz_PausedOracleAndEligibleDelegateHasEarningPower(
    address _delegate,
    uint256 _votingPower,
    uint256 _unusedParam1,
    address _unusedParam2
  ) public {
    _setOracleAsUnavailableAsOraclePaused();
    _setDelegateeAsEligibleWithVotingPower(_delegate, _votingPower);

    uint256 _expectedVotingPower = uint256(Math.sqrt(_votingPower));

    assertEq(
      calculator.getEarningPower(_unusedParam1, _delegate, _unusedParam2), _expectedVotingPower
    );
  }

  // Oracle is stale && delegate IS eligible → return sqrt(votingPower)
  function testFuzz_StaleOracleAndEligibleDelegateHasEarningPower(
    address _delegate,
    uint256 _votingPower,
    uint256 _unusedParam1,
    address _unusedParam2
  ) public {
    _setOracleAsUnavailableAsOracleStale();
    _setDelegateeAsEligibleWithVotingPower(_delegate, _votingPower);

    uint256 _expectedVotingPower = uint256(Math.sqrt(_votingPower));

    assertEq(
      calculator.getEarningPower(_unusedParam1, _delegate, _unusedParam2), _expectedVotingPower
    );
  }

  // Oracle is paused && delegate IS NOT eligible → return sqrt(votingPower)
  function testFuzz_PausedOracleAndIneligibleDelegateHasEarningPower(
    address _delegate,
    uint256 _votingPower,
    uint256 _unusedParam1,
    address _unusedParam2
  ) public {
    _setOracleAsUnavailableAsOraclePaused();
    _setOracleAsUnavailableAsOracleStale();
    _setDelegateeAsNotEligibleWithVotingPower(_delegate, _votingPower);

    uint256 _expectedVotingPower = uint256(Math.sqrt(_votingPower));

    assertEq(
      calculator.getEarningPower(_unusedParam1, _delegate, _unusedParam2), _expectedVotingPower
    );
  }

  // Oracle is stale && delegate IS NOT eligible → return sqrt(votingPower)
  function testFuzz_StaleOracleAndIneligibleDelegateHasEarningPower(
    address _delegate,
    uint256 _votingPower,
    uint256 _unusedParam1,
    address _unusedParam2
  ) public {
    _setOracleAsUnavailableAsOracleStale();
    _setDelegateeAsNotEligibleWithVotingPower(_delegate, _votingPower);

    uint256 _expectedVotingPower = uint256(Math.sqrt(_votingPower));

    assertEq(
      calculator.getEarningPower(_unusedParam1, _delegate, _unusedParam2), _expectedVotingPower
    );
  }

  // Oracle is available && delegate IS NOT eligible → return 0
  function testFuzz_AvailableOracleAndIneligibleDelegateHasZeroEarningPower(
    address _delegate,
    uint256 _votingPower,
    uint256 _unusedParam1,
    address _unusedParam2
  ) public {
    _setOracleAsAvailable();
    _setDelegateeAsNotEligibleWithVotingPower(_delegate, _votingPower);

    assertEq(calculator.getEarningPower(_unusedParam1, _delegate, _unusedParam2), 0);
  }
}

contract GetNewEarningPower is BinaryVotingPowerCalculatorTest {
  // Oracle is available && delegate IS eligible → return (sqrt(votingPower), true)
  function testFuzz_AvailableOracleAndEligibleDelegateHasEarningPower(
    address _delegate,
    uint256 _votingPower,
    uint256 _oldEarningPower,
    uint256 _unusedParam1,
    address _unusedParam2
  ) public {
    _setOracleAsAvailable();
    _setDelegateeAsEligibleWithVotingPower(_delegate, _votingPower);

    uint256 _expectedVotingPower = uint256(Math.sqrt(_votingPower));
    (uint256 _actualVotingPower, bool _isQualifiedForBump) =
      calculator.getNewEarningPower(_unusedParam1, _delegate, _unusedParam2, _oldEarningPower);

    assertEq(_actualVotingPower, _expectedVotingPower);
    assertTrue(_isQualifiedForBump);
  }

  // Oracle is paused && delegate IS eligible → return (sqrt(votingPower), true)
  function testFuzz_PausedOracleAndEligibleDelegateHasEarningPower(
    address _delegate,
    uint256 _votingPower,
    uint256 _oldEarningPower,
    uint256 _unusedParam1,
    address _unusedParam2
  ) public {
    _setOracleAsUnavailableAsOraclePaused();
    _setDelegateeAsEligibleWithVotingPower(_delegate, _votingPower);

    uint256 _expectedVotingPower = uint256(Math.sqrt(_votingPower));
    (uint256 _actualVotingPower, bool _isQualifiedForBump) =
      calculator.getNewEarningPower(_unusedParam1, _delegate, _unusedParam2, _oldEarningPower);

    assertEq(_actualVotingPower, _expectedVotingPower);
    assertTrue(_isQualifiedForBump);
  }

  // Oracle is stale && delegate IS eligible → return (sqrt(votingPower), true)
  function testFuzz_StaleOracleAndEligibleDelegateHasEarningPower(
    address _delegate,
    uint256 _votingPower,
    uint256 _oldEarningPower,
    uint256 _unusedParam1,
    address _unusedParam2
  ) public {
    _setOracleAsUnavailableAsOracleStale();
    _setDelegateeAsEligibleWithVotingPower(_delegate, _votingPower);

    uint256 _expectedVotingPower = uint256(Math.sqrt(_votingPower));
    (uint256 _actualVotingPower, bool _isQualifiedForBump) =
      calculator.getNewEarningPower(_unusedParam1, _delegate, _unusedParam2, _oldEarningPower);

    assertEq(_actualVotingPower, _expectedVotingPower);
    assertTrue(_isQualifiedForBump);
  }

  // Oracle is available && delegate IS NOT eligible → return (0, true)
  function testFuzz_AvailableOracleAndIneligibleDelegateHasZeroEarningPower(
    address _delegate,
    uint256 _votingPower,
    uint256 _oldEarningPower,
    uint256 _unusedParam1,
    address _unusedParam2
  ) public {
    _setOracleAsAvailable();
    _setDelegateeAsNotEligibleWithVotingPower(_delegate, _votingPower);

    (uint256 _actualVotingPower, bool _isQualifiedForBump) =
      calculator.getNewEarningPower(_unusedParam1, _delegate, _unusedParam2, _oldEarningPower);

    assertEq(_actualVotingPower, 0);
    assertTrue(_isQualifiedForBump);
  }

  // Oracle is paused && delegate IS NOT eligible → return (sqrt(votingPower), true)
  function testFuzz_PausedOracleAndIneligibleDelegateHasEarningPower(
    address _delegate,
    uint256 _votingPower,
    uint256 _oldEarningPower,
    uint256 _unusedParam1,
    address _unusedParam2
  ) public {
    _setOracleAsUnavailableAsOraclePaused();
    _setDelegateeAsNotEligibleWithVotingPower(_delegate, _votingPower);

    uint256 _expectedVotingPower = uint256(Math.sqrt(_votingPower));
    (uint256 _actualVotingPower, bool _isQualifiedForBump) =
      calculator.getNewEarningPower(_unusedParam1, _delegate, _unusedParam2, _oldEarningPower);

    assertEq(_actualVotingPower, _expectedVotingPower);
    assertTrue(_isQualifiedForBump);
  }

  // Oracle is stale && delegate IS NOT eligible → return (sqrt(votingPower), true)
  function testFuzz_StaleOracleAndIneligibleDelegateHasEarningPower(
    address _delegate,
    uint256 _votingPower,
    uint256 _oldEarningPower,
    uint256 _unusedParam1,
    address _unusedParam2
  ) public {
    _setOracleAsUnavailableAsOracleStale();
    _setDelegateeAsNotEligibleWithVotingPower(_delegate, _votingPower);

    uint256 _expectedVotingPower = uint256(Math.sqrt(_votingPower));
    (uint256 _actualVotingPower, bool _isQualifiedForBump) =
      calculator.getNewEarningPower(_unusedParam1, _delegate, _unusedParam2, _oldEarningPower);

    assertEq(_actualVotingPower, _expectedVotingPower);
    assertTrue(_isQualifiedForBump);
  }
}

contract SetEligibilityModule is BinaryVotingPowerCalculatorTest {
  function testFuzz_SetsEligibilityModule(address _eligibilityModule) public {
    _assumeSafeEligibilityModule(_eligibilityModule);
    vm.assume(_eligibilityModule != address(calculator.eligibilityModule()));

    vm.prank(owner);
    calculator.setEligibilityModule(_eligibilityModule);
    assertEq(address(calculator.eligibilityModule()), _eligibilityModule);
  }

  function testFuzz_EmitsEligibilityModuleSetEvent(address _eligibilityModule) public {
    _assumeSafeEligibilityModule(_eligibilityModule);
    vm.assume(_eligibilityModule != address(calculator.eligibilityModule()));

    vm.expectEmit();
    emit BinaryVotingPowerCalculator.EligibilityModuleSet(
      address(calculator.eligibilityModule()), _eligibilityModule
    );
    vm.prank(owner);
    calculator.setEligibilityModule(_eligibilityModule);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(address _eligibilityModule) public {
    address notOwner = makeAddr("notOwner");
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
    vm.prank(notOwner);
    calculator.setEligibilityModule(_eligibilityModule);
  }
}

contract SetVotingPowerUpdateInterval is BinaryVotingPowerCalculatorTest {
  function testFuzz_SetsVotingPowerUpdateInterval(uint48 _votingPowerUpdateInterval) public {
    _assumeSafeVotingPowerUpdateInterval(_votingPowerUpdateInterval);
    vm.assume(_votingPowerUpdateInterval != calculator.votingPowerUpdateInterval());

    vm.prank(owner);
    calculator.setVotingPowerUpdateInterval(_votingPowerUpdateInterval);
    assertEq(calculator.votingPowerUpdateInterval(), _votingPowerUpdateInterval);
  }

  function testFuzz_EmitsVotingPowerUpdateIntervalSetEvent(uint48 _votingPowerUpdateInterval)
    public
  {
    _assumeSafeVotingPowerUpdateInterval(_votingPowerUpdateInterval);
    vm.assume(_votingPowerUpdateInterval != calculator.votingPowerUpdateInterval());

    vm.expectEmit();
    emit BinaryVotingPowerCalculator.VotingPowerUpdateIntervalSet(
      calculator.votingPowerUpdateInterval(), _votingPowerUpdateInterval
    );
    vm.prank(owner);
    calculator.setVotingPowerUpdateInterval(_votingPowerUpdateInterval);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(uint48 _votingPowerUpdateInterval) public {
    address notOwner = makeAddr("notOwner");
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
    vm.prank(notOwner);
    calculator.setVotingPowerUpdateInterval(_votingPowerUpdateInterval);
  }
}
