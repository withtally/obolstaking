// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {MockVotingPowerToken} from "test/mocks/MockVotingPowerToken.sol";

import {MockOracleEligibilityModule} from "test/mocks/MockOracleEligibilityModule.sol";
import {BinaryVotingPowerEarningPowerCalculator} from
  "src/calculators/BinaryVotingPowerEarningPowerCalculator.sol";

contract BinaryVotingPowerEarningPowerCalculatorTest is Test {
  BinaryVotingPowerEarningPowerCalculator public calculator;
  MockOracleEligibilityModule public mockEligibilityModule;
  MockVotingPowerToken public mockVotingPowerToken;
  address public owner = makeAddr("owner");
  uint48 public votingPowerUpdateInterval = 100;

  function setUp() public {
    mockEligibilityModule = new MockOracleEligibilityModule();
    mockVotingPowerToken = new MockVotingPowerToken();
    calculator = new BinaryVotingPowerEarningPowerCalculator(
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

  function _assumeSafeOracleEligibilityModule(address _oracleEligibilityModule) internal pure {
    vm.assume(_oracleEligibilityModule != address(0));
  }

  function _assumeSafeInitialParameters(
    address _owner,
    address _votingPowerToken,
    uint48 _votingPowerUpdateInterval,
    address _oracleEligibilityModule
  ) internal pure {
    _assumeSafeOwner(_owner);
    _assumeSafeVotingPowerToken(_votingPowerToken);
    _assumeSafeVotingPowerUpdateInterval(_votingPowerUpdateInterval);
    _assumeSafeOracleEligibilityModule(_oracleEligibilityModule);
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

contract Constructor is BinaryVotingPowerEarningPowerCalculatorTest {
  function testFuzz_SetsInitialParameters(
    address _owner,
    address _votingPowerToken,
    uint48 _votingPowerUpdateInterval,
    address _oracleEligibilityModule
  ) public {
    _assumeSafeInitialParameters(
      _owner, _votingPowerToken, _votingPowerUpdateInterval, _oracleEligibilityModule
    );

    BinaryVotingPowerEarningPowerCalculator _calculator = new BinaryVotingPowerEarningPowerCalculator(
      _owner, _oracleEligibilityModule, _votingPowerToken, _votingPowerUpdateInterval
    );

    assertEq(_calculator.owner(), _owner);
    assertEq(_calculator.VOTING_POWER_TOKEN(), _votingPowerToken);
    assertEq(_calculator.votingPowerUpdateInterval(), _votingPowerUpdateInterval);
    assertEq(address(_calculator.oracleEligibilityModule()), _oracleEligibilityModule);
    assertEq(_calculator.SNAPSHOT_START_BLOCK(), uint48(block.number));
  }

  function testFuzz_EmitsOracleEligibilityModuleSetEvent(
    address _owner,
    address _votingPowerToken,
    uint48 _votingPowerUpdateInterval,
    address _oracleEligibilityModule
  ) public {
    _assumeSafeInitialParameters(
      _owner, _votingPowerToken, _votingPowerUpdateInterval, _oracleEligibilityModule
    );

    vm.expectEmit();
    emit BinaryVotingPowerEarningPowerCalculator.OracleEligibilityModuleSet(
      address(0), _oracleEligibilityModule
    );
    new BinaryVotingPowerEarningPowerCalculator(
      _owner, _oracleEligibilityModule, _votingPowerToken, _votingPowerUpdateInterval
    );
  }

  function testFuzz_RevertIf_OwnerIsZeroAddress(
    address _votingPowerToken,
    uint48 _votingPowerUpdateInterval,
    address _oracleEligibilityModule
  ) public {
    _assumeSafeVotingPowerToken(_votingPowerToken);
    _assumeSafeVotingPowerUpdateInterval(_votingPowerUpdateInterval);
    _assumeSafeOracleEligibilityModule(_oracleEligibilityModule);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
    new BinaryVotingPowerEarningPowerCalculator(
      address(0), _oracleEligibilityModule, _votingPowerToken, _votingPowerUpdateInterval
    );
  }

  function testFuzz_RevertIf_OracleEligibilityModuleIsZeroAddress(
    address _owner,
    address _votingPowerToken,
    uint48 _votingPowerUpdateInterval
  ) public {
    _assumeSafeOwner(_owner);
    _assumeSafeVotingPowerToken(_votingPowerToken);
    _assumeSafeVotingPowerUpdateInterval(_votingPowerUpdateInterval);

    vm.expectRevert(
      BinaryVotingPowerEarningPowerCalculator
        .BinaryVotingPowerEarningPowerCalculator__InvalidAddress
        .selector
    );
    new BinaryVotingPowerEarningPowerCalculator(
      _owner, address(0), _votingPowerToken, _votingPowerUpdateInterval
    );
  }

  function testFuzz_RevertIf_VotingPowerTokenIsZeroAddress(
    address _owner,
    uint48 _votingPowerUpdateInterval,
    address _oracleEligibilityModule
  ) public {
    _assumeSafeOwner(_owner);
    _assumeSafeVotingPowerUpdateInterval(_votingPowerUpdateInterval);
    _assumeSafeOracleEligibilityModule(_oracleEligibilityModule);

    vm.expectRevert(
      BinaryVotingPowerEarningPowerCalculator
        .BinaryVotingPowerEarningPowerCalculator__InvalidAddress
        .selector
    );
    new BinaryVotingPowerEarningPowerCalculator(
      _owner, _oracleEligibilityModule, address(0), _votingPowerUpdateInterval
    );
  }

  function testFuzz_RevertIf_VotingPowerUpdateIntervalIsZero(
    address _owner,
    address _votingPowerToken,
    address _oracleEligibilityModule
  ) public {
    _assumeSafeOwner(_owner);
    _assumeSafeVotingPowerToken(_votingPowerToken);
    _assumeSafeOracleEligibilityModule(_oracleEligibilityModule);

    vm.expectRevert(
      BinaryVotingPowerEarningPowerCalculator
        .BinaryVotingPowerEarningPowerCalculator__InvalidVotingPowerUpdateInterval
        .selector
    );
    new BinaryVotingPowerEarningPowerCalculator(
      _owner, _oracleEligibilityModule, _votingPowerToken, 0
    );
  }
}

contract GetEarningPower is BinaryVotingPowerEarningPowerCalculatorTest {
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

  // Oracle is paused → return sqrt(votingPower) regardless of eligibility
  function testFuzz_PausedOracleReturnsVotingPowerRegardlessOfEligibility(
    address _delegate,
    uint256 _votingPower,
    uint256 _unusedParam1,
    address _unusedParam2
  ) public {
    _setOracleAsUnavailableAsOraclePaused();
    _setVotingPowerForDelegate(_delegate, _votingPower);

    uint256 _expectedVotingPower = uint256(Math.sqrt(_votingPower));

    // Test with eligible delegate
    _setDelegateeAsEligibleWithVotingPower(_delegate, _votingPower);
    assertEq(
      calculator.getEarningPower(_unusedParam1, _delegate, _unusedParam2), _expectedVotingPower
    );

    // Test with ineligible delegate
    _setDelegateeAsNotEligibleWithVotingPower(_delegate, _votingPower);
    assertEq(
      calculator.getEarningPower(_unusedParam1, _delegate, _unusedParam2), _expectedVotingPower
    );
  }

  // Oracle is stale → return sqrt(votingPower) regardless of eligibility
  function testFuzz_StaleOracleReturnsVotingPowerRegardlessOfEligibility(
    address _delegate,
    uint256 _votingPower,
    uint256 _unusedParam1,
    address _unusedParam2
  ) public {
    _setOracleAsUnavailableAsOracleStale();
    _setVotingPowerForDelegate(_delegate, _votingPower);

    uint256 _expectedVotingPower = uint256(Math.sqrt(_votingPower));

    // Test with eligible delegate
    _setDelegateeAsEligibleWithVotingPower(_delegate, _votingPower);
    assertEq(
      calculator.getEarningPower(_unusedParam1, _delegate, _unusedParam2), _expectedVotingPower
    );

    // Test with ineligible delegate
    _setDelegateeAsNotEligibleWithVotingPower(_delegate, _votingPower);
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

contract GetNewEarningPower is BinaryVotingPowerEarningPowerCalculatorTest {
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

  // Oracle is paused → return (sqrt(votingPower), true) regardless of eligibility
  function testFuzz_PausedOracleReturnsVotingPowerRegardlessOfEligibility(
    address _delegate,
    uint256 _votingPower,
    uint256 _oldEarningPower,
    uint256 _unusedParam1,
    address _unusedParam2
  ) public {
    _setOracleAsUnavailableAsOraclePaused();
    _setVotingPowerForDelegate(_delegate, _votingPower);

    uint256 _expectedVotingPower = uint256(Math.sqrt(_votingPower));

    // Test with eligible delegate
    _setDelegateeAsEligibleWithVotingPower(_delegate, _votingPower);
    (uint256 _actualVotingPower, bool _isQualifiedForBump) =
      calculator.getNewEarningPower(_unusedParam1, _delegate, _unusedParam2, _oldEarningPower);
    assertEq(_actualVotingPower, _expectedVotingPower);
    assertTrue(_isQualifiedForBump);

    // Test with ineligible delegate
    _setDelegateeAsNotEligibleWithVotingPower(_delegate, _votingPower);
    (uint256 _actualVotingPower2, bool _isQualifiedForBump2) =
      calculator.getNewEarningPower(_unusedParam1, _delegate, _unusedParam2, _oldEarningPower);
    assertEq(_actualVotingPower2, _expectedVotingPower);
    assertTrue(_isQualifiedForBump2);
  }

  // Oracle is stale → return (sqrt(votingPower), true) regardless of eligibility
  function testFuzz_StaleOracleReturnsVotingPowerRegardlessOfEligibility(
    address _delegate,
    uint256 _votingPower,
    uint256 _oldEarningPower,
    uint256 _unusedParam1,
    address _unusedParam2
  ) public {
    _setOracleAsUnavailableAsOracleStale();
    _setVotingPowerForDelegate(_delegate, _votingPower);

    uint256 _expectedVotingPower = uint256(Math.sqrt(_votingPower));

    // Test with eligible delegate
    _setDelegateeAsEligibleWithVotingPower(_delegate, _votingPower);
    (uint256 _actualVotingPower, bool _isQualifiedForBump) =
      calculator.getNewEarningPower(_unusedParam1, _delegate, _unusedParam2, _oldEarningPower);
    assertEq(_actualVotingPower, _expectedVotingPower);
    assertTrue(_isQualifiedForBump);

    // Test with ineligible delegate
    _setDelegateeAsNotEligibleWithVotingPower(_delegate, _votingPower);
    (uint256 _actualVotingPower2, bool _isQualifiedForBump2) =
      calculator.getNewEarningPower(_unusedParam1, _delegate, _unusedParam2, _oldEarningPower);
    assertEq(_actualVotingPower2, _expectedVotingPower);
    assertTrue(_isQualifiedForBump2);
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
}

contract SetOracleEligibilityModule is BinaryVotingPowerEarningPowerCalculatorTest {
  function testFuzz_SetsOracleEligibilityModule(address _oracleEligibilityModule) public {
    _assumeSafeOracleEligibilityModule(_oracleEligibilityModule);

    vm.prank(owner);
    calculator.setOracleEligibilityModule(_oracleEligibilityModule);
    assertEq(address(calculator.oracleEligibilityModule()), _oracleEligibilityModule);
  }

  function testFuzz_EmitsOracleEligibilityModuleSetEvent(address _oracleEligibilityModule) public {
    _assumeSafeOracleEligibilityModule(_oracleEligibilityModule);

    vm.expectEmit();
    emit BinaryVotingPowerEarningPowerCalculator.OracleEligibilityModuleSet(
      address(calculator.oracleEligibilityModule()), _oracleEligibilityModule
    );
    vm.prank(owner);
    calculator.setOracleEligibilityModule(_oracleEligibilityModule);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(address _oracleEligibilityModule, address _caller)
    public
  {
    vm.assume(_caller != owner);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    vm.prank(_caller);
    calculator.setOracleEligibilityModule(_oracleEligibilityModule);
  }
}

contract SetVotingPowerUpdateInterval is BinaryVotingPowerEarningPowerCalculatorTest {
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
    emit BinaryVotingPowerEarningPowerCalculator.VotingPowerUpdateIntervalSet(
      calculator.votingPowerUpdateInterval(), _votingPowerUpdateInterval
    );
    vm.prank(owner);
    calculator.setVotingPowerUpdateInterval(_votingPowerUpdateInterval);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(uint48 _votingPowerUpdateInterval, address _caller)
    public
  {
    vm.assume(_caller != owner);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    vm.prank(_caller);
    calculator.setVotingPowerUpdateInterval(_votingPowerUpdateInterval);
  }
}
