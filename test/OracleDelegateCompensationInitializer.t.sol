// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {OracleDelegateCompensationInitializer} from "src/OracleDelegateCompensationInitializer.sol";
import {IOracleEligibilityModule} from "src/interfaces/IOracleEligibilityModule.sol";

import {MockVotingPowerToken} from "test/mocks/MockVotingPowerToken.sol";
import {MockOracleEligibilityModule} from "test/mocks/MockOracleEligibilityModule.sol";
import {DelegateCompensationStaker} from "src/DelegateCompensationStaker.sol";
import {Staker} from "staker/Staker.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Fake} from "staker-test/fakes/ERC20Fake.sol";
import {MockEarningPowerCalculator} from "test/mocks/MockEarningPowerCalculator.sol";
import {DelegateCompensationStakerTest} from "test/helpers/DelegateCompensationStakerTest.sol";

contract OracleDelegateCompensationInitializerFake is OracleDelegateCompensationInitializer {
  IOracleEligibilityModule public immutable ORACLE_ELIGIBILITY_MODULE;

  constructor(
    address _owner,
    address _delegateCompensationStaker,
    address _oracleEligibilityModule,
    address _scoreOracle
  )
    Ownable(_owner)
    OracleDelegateCompensationInitializer(_delegateCompensationStaker, _scoreOracle)
  {
    ORACLE_ELIGIBILITY_MODULE = IOracleEligibilityModule(_oracleEligibilityModule);
  }

  function getOracleEligibilityModule()
    public
    view
    virtual
    override
    returns (IOracleEligibilityModule)
  {
    return ORACLE_ELIGIBILITY_MODULE;
  }
}

contract OracleDelegateCompensationInitializerTest is DelegateCompensationStakerTest {
  OracleDelegateCompensationInitializer delegateCompInitializer;
  address public owner;
  address public scoreOracle;
  DelegateCompensationStaker public delegateCompStaker;
  MockOracleEligibilityModule public mockEligibilityModule;
  MockVotingPowerToken public mockVotingPowerToken;
  MockEarningPowerCalculator public earningPowerCalculator;

  function setUp() public override {
    super.setUp();
    owner = makeAddr("owner");
    scoreOracle = makeAddr("scoreOracle");
    admin = makeAddr("admin");

    earningPowerCalculator = new MockEarningPowerCalculator();

    // Deploy DelegateCompensationStaker
    delegateCompStaker = new DelegateCompensationStaker(
      IERC20(address(rewardToken)), earningPowerCalculator, MAX_BUMP_TIP, admin
    );

    mockEligibilityModule = new MockOracleEligibilityModule();
    mockVotingPowerToken = new MockVotingPowerToken();
    delegateCompInitializer = new OracleDelegateCompensationInitializerFake(
      owner, address(delegateCompStaker), address(mockEligibilityModule), scoreOracle
    );
  }
}

contract UpdateDelegateeScore is OracleDelegateCompensationInitializerTest {
  function testFuzz_UpdatesScoreWhenNotEligible(address _delegatee, uint256 _score) public {
    // Set delegatee as not eligible
    mockEligibilityModule.__setMockDelegateeEligibility(_delegatee, false);

    uint256 _startingDepositIdentifier =
      Staker.DepositIdentifier.unwrap(delegateCompStaker.delegateDepositId(_delegatee));

    vm.prank(scoreOracle);
    delegateCompInitializer.updateDelegateeScore(_delegatee, _score);

    // Verify delegate remains uninitialized
    assertEq(_startingDepositIdentifier, 0);
    assertEq(Staker.DepositIdentifier.unwrap(delegateCompStaker.delegateDepositId(_delegatee)), 0);
  }

  function testFuzz_UpdatesScoreWhenDelegateInitialized(address _delegatee, uint256 _score) public {
    _score = bound(_score, 0, type(uint256).max - 1);

    // Set delegatee as eligible
    mockEligibilityModule.__setMockDelegateeEligibility(_delegatee, true);
    earningPowerCalculator.setDelegateEarningPower(_delegatee, 100e18);

    vm.prank(scoreOracle);
    delegateCompInitializer.updateDelegateeScore(_delegatee, _score);

    uint256 _initializedDepositId =
      Staker.DepositIdentifier.unwrap(delegateCompStaker.delegateDepositId(_delegatee));

    vm.prank(scoreOracle);
    delegateCompInitializer.updateDelegateeScore(_delegatee, _score + 1);

    // Verify the deposit ID hasn't changed after second score update
    assertEq(
      Staker.DepositIdentifier.unwrap(delegateCompStaker.delegateDepositId(_delegatee)),
      _initializedDepositId
    );
    assertEq(_initializedDepositId, 1);
  }

  function testFuzz_InitializesDelegateWhenAboveThresholdAndNotInitialized(
    address _delegatee,
    uint256 _score
  ) public {
    // Set delegatee as eligible
    mockEligibilityModule.__setMockDelegateeEligibility(_delegatee, true);
    earningPowerCalculator.setDelegateEarningPower(_delegatee, 100e18);

    // Ensure delegate is not initialized
    assertEq(Staker.DepositIdentifier.unwrap(delegateCompStaker.delegateDepositId(_delegatee)), 0);

    // Expect the initialization event
    vm.expectEmit();
    emit DelegateCompensationStaker.DelegateCompensation__Initialized(
      _delegatee, Staker.DepositIdentifier.wrap(1), 100e18
    );

    // Call updateDelegateeScore
    vm.prank(scoreOracle);
    delegateCompInitializer.updateDelegateeScore(_delegatee, _score);

    // Verify delegate is now initialized
    assertEq(Staker.DepositIdentifier.unwrap(delegateCompStaker.delegateDepositId(_delegatee)), 1);
  }

  function testFuzz_RevertIf_CallerIsNotScoreOracle(
    address _caller,
    address _delegatee,
    uint256 _score
  ) public {
    vm.assume(_caller != scoreOracle);
    vm.prank(_caller);
    vm.expectRevert(
      abi.encodeWithSelector(
        OracleDelegateCompensationInitializer
          .OracleDelegateCompensationInitializer__Unauthorized
          .selector,
        bytes32("not oracle"),
        _caller
      )
    );
    delegateCompInitializer.updateDelegateeScore(_delegatee, _score);
  }
}

contract UpdateDelegateeScores is OracleDelegateCompensationInitializerTest {
  function testFuzz_UpdateASingleDelegateeScoreOnce(
    address[1] memory _delegatees,
    uint256[1] memory _scores
  ) public {
    _assumeValidDelegate(_delegatees[0]);
    IOracleEligibilityModule.DelegateeScoreUpdate[] memory updates =
      new IOracleEligibilityModule.DelegateeScoreUpdate[](3);

    updates[0] = IOracleEligibilityModule.DelegateeScoreUpdate({
      delegatee: _delegatees[0],
      newScore: _scores[0]
    });

    mockEligibilityModule.__setMockDelegateeEligibility(_delegatees[0], true);

    vm.prank(scoreOracle);
    delegateCompInitializer.updateDelegateeScores(updates);

    // Deposits have been created
    assertEq(
      Staker.DepositIdentifier.unwrap(delegateCompStaker.delegateDepositId(_delegatees[0])), 1
    );
    assertEq(mockEligibilityModule.__delegateeScores(_delegatees[0]), _scores[0]);
  }

  function testFuzz_UpdateASingleDelegateeScoreMultipleTimes(
    address[1] memory _delegatees,
    uint256[2] memory _scores
  ) public {
    _assumeValidDelegate(_delegatees[0]);
    IOracleEligibilityModule.DelegateeScoreUpdate[] memory updates =
      new IOracleEligibilityModule.DelegateeScoreUpdate[](3);

    updates[0] = IOracleEligibilityModule.DelegateeScoreUpdate({
      delegatee: _delegatees[0],
      newScore: _scores[0]
    });
    updates[1] = IOracleEligibilityModule.DelegateeScoreUpdate({
      delegatee: _delegatees[0],
      newScore: _scores[1]
    });

    mockEligibilityModule.__setMockDelegateeEligibility(_delegatees[0], true);

    vm.prank(scoreOracle);
    delegateCompInitializer.updateDelegateeScores(updates);

    // Deposits have been created
    assertEq(
      Staker.DepositIdentifier.unwrap(delegateCompStaker.delegateDepositId(_delegatees[0])), 1
    );
    assertEq(mockEligibilityModule.__delegateeScores(_delegatees[0]), _scores[1]);
  }

  function testFuzz_UpdatesMultipleDelegateeScoresAtOnce(
    address[3] memory _delegatees,
    uint256[3] memory _scores
  ) public {
    vm.assume(
      _delegatees[0] != _delegatees[1] && _delegatees[1] != _delegatees[2]
        && _delegatees[0] != _delegatees[2]
    );

    IOracleEligibilityModule.DelegateeScoreUpdate[] memory updates =
      new IOracleEligibilityModule.DelegateeScoreUpdate[](3);

    updates[0] = IOracleEligibilityModule.DelegateeScoreUpdate({
      delegatee: _delegatees[0],
      newScore: _scores[0]
    });
    updates[1] = IOracleEligibilityModule.DelegateeScoreUpdate({
      delegatee: _delegatees[1],
      newScore: _scores[1]
    });
    updates[2] = IOracleEligibilityModule.DelegateeScoreUpdate({
      delegatee: _delegatees[2],
      newScore: _scores[2]
    });

    for (uint256 i = 0; i < 3; i++) {
      mockEligibilityModule.__setMockDelegateeEligibility(_delegatees[i], true);
    }

    vm.prank(scoreOracle);
    delegateCompInitializer.updateDelegateeScores(updates);

    // Deposits have been created
    assertEq(
      Staker.DepositIdentifier.unwrap(delegateCompStaker.delegateDepositId(_delegatees[0])), 1
    );
    assertEq(
      Staker.DepositIdentifier.unwrap(delegateCompStaker.delegateDepositId(_delegatees[1])), 2
    );
    assertEq(
      Staker.DepositIdentifier.unwrap(delegateCompStaker.delegateDepositId(_delegatees[2])), 3
    );

    // Verify scores were stored correctly
    assertEq(mockEligibilityModule.__delegateeScores(_delegatees[0]), _scores[0]);
    assertEq(mockEligibilityModule.__delegateeScores(_delegatees[1]), _scores[1]);
    assertEq(mockEligibilityModule.__delegateeScores(_delegatees[2]), _scores[2]);
  }

  function testFuzz_EmitsAnEventForEachDelegateeSInitialized(
    address[3] memory _delegatees,
    uint256[3] memory _scores,
    uint256[3] memory _earningPowers
  ) public {
    vm.assume(
      _delegatees[0] != _delegatees[1] && _delegatees[1] != _delegatees[2]
        && _delegatees[0] != _delegatees[2]
    );
    _earningPowers[0] = bound(_earningPowers[0], 1, type(uint96).max);
    _earningPowers[1] = bound(_earningPowers[1], 1, type(uint96).max);
    _earningPowers[2] = bound(_earningPowers[2], 1, type(uint96).max);

    IOracleEligibilityModule.DelegateeScoreUpdate[] memory updates =
      new IOracleEligibilityModule.DelegateeScoreUpdate[](3);

    updates[0] = IOracleEligibilityModule.DelegateeScoreUpdate({
      delegatee: _delegatees[0],
      newScore: _scores[0]
    });
    updates[1] = IOracleEligibilityModule.DelegateeScoreUpdate({
      delegatee: _delegatees[1],
      newScore: _scores[1]
    });
    updates[2] = IOracleEligibilityModule.DelegateeScoreUpdate({
      delegatee: _delegatees[2],
      newScore: _scores[2]
    });

    for (uint256 i = 0; i < 3; i++) {
      mockEligibilityModule.__setMockDelegateeEligibility(_delegatees[i], true);
      earningPowerCalculator.setDelegateEarningPower(_delegatees[i], _earningPowers[i]);
    }

    vm.expectEmit();
    emit DelegateCompensationStaker.DelegateCompensation__Initialized(
      _delegatees[0], Staker.DepositIdentifier.wrap(1), _earningPowers[0]
    );
    vm.expectEmit();
    emit DelegateCompensationStaker.DelegateCompensation__Initialized(
      _delegatees[1], Staker.DepositIdentifier.wrap(2), _earningPowers[1]
    );
    vm.expectEmit();
    emit DelegateCompensationStaker.DelegateCompensation__Initialized(
      _delegatees[2], Staker.DepositIdentifier.wrap(3), _earningPowers[2]
    );

    vm.prank(scoreOracle);
    delegateCompInitializer.updateDelegateeScores(updates);
  }

  function testFuzz_UpdatesMixedEligibilityStates(
    address[4] memory _delegatees,
    uint256[4] memory _scores,
    uint256[2] memory _earningPowers
  ) public {
    vm.assume(
      _delegatees[0] != _delegatees[1] && _delegatees[1] != _delegatees[2]
        && _delegatees[2] != _delegatees[3] && _delegatees[0] != _delegatees[2]
        && _delegatees[0] != _delegatees[3] && _delegatees[1] != _delegatees[3]
    );
    _earningPowers[0] = bound(_earningPowers[0], 1, type(uint96).max);
    _earningPowers[1] = bound(_earningPowers[1], 1, type(uint96).max);

    IOracleEligibilityModule.DelegateeScoreUpdate[] memory updates =
      new IOracleEligibilityModule.DelegateeScoreUpdate[](4);

    for (uint256 i = 0; i < 4; i++) {
      updates[i] = IOracleEligibilityModule.DelegateeScoreUpdate({
        delegatee: _delegatees[i],
        newScore: _scores[i]
      });
    }

    // Set mixed eligibility states - alternating eligible/not eligible
    mockEligibilityModule.__setMockDelegateeEligibility(_delegatees[0], true);
    mockEligibilityModule.__setMockDelegateeEligibility(_delegatees[1], false);
    mockEligibilityModule.__setMockDelegateeEligibility(_delegatees[2], true);
    mockEligibilityModule.__setMockDelegateeEligibility(_delegatees[3], false);

    earningPowerCalculator.setDelegateEarningPower(_delegatees[0], _earningPowers[0]);
    earningPowerCalculator.setDelegateEarningPower(_delegatees[2], _earningPowers[1]);

    // Initialize delegatee[2] beforehand to test already initialized case
    DelegateCompensationStaker.DepositIdentifier delegatee2DepositId =
      delegateCompStaker.initializeDelegateCompensation(_delegatees[2]);

    vm.prank(scoreOracle);
    delegateCompInitializer.updateDelegateeScores(updates);

    // Check results
    assertEq(
      Staker.DepositIdentifier.unwrap(delegateCompStaker.delegateDepositId(_delegatees[0])), 2
    );
    assertEq(
      Staker.DepositIdentifier.unwrap(delegateCompStaker.delegateDepositId(_delegatees[1])), 0
    );
    assertEq(delegateCompStaker.delegateDepositId(_delegatees[2]), delegatee2DepositId);
    assertEq(
      Staker.DepositIdentifier.unwrap(delegateCompStaker.delegateDepositId(_delegatees[3])), 0
    );
  }

  function test_GivenEmptyArray() public {
    IOracleEligibilityModule.DelegateeScoreUpdate[] memory updates =
      new IOracleEligibilityModule.DelegateeScoreUpdate[](0);

    vm.prank(scoreOracle);
    delegateCompInitializer.updateDelegateeScores(updates);
  }

  function testFuzz_RevertIf_CallerIsNotScoreOracle(
    address _caller,
    IOracleEligibilityModule.DelegateeScoreUpdate[] memory _updates
  ) public {
    vm.assume(_caller != scoreOracle);

    vm.prank(_caller);
    vm.expectRevert(
      abi.encodeWithSelector(
        OracleDelegateCompensationInitializer
          .OracleDelegateCompensationInitializer__Unauthorized
          .selector,
        bytes32("not oracle"),
        _caller
      )
    );
    delegateCompInitializer.updateDelegateeScores(_updates);
  }
}

contract SetScoreOracle is OracleDelegateCompensationInitializerTest {
  function testFuzz_SetsTheScoreOracleAddress(address _newScoreOracle) public {
    vm.prank(owner);
    delegateCompInitializer.setScoreOracle(_newScoreOracle);
    assertEq(delegateCompInitializer.scoreOracle(), _newScoreOracle);
  }

  function testFuzz_EmitsAnEventWhenScoreOracleIsUpdated(address _newScoreOracle) public {
    vm.prank(owner);
    vm.expectEmit();
    emit OracleDelegateCompensationInitializer.ScoreOracleSet(scoreOracle, _newScoreOracle);
    delegateCompInitializer.setScoreOracle(_newScoreOracle);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(address _caller, address _newScoreOracle) public {
    vm.assume(_caller != owner);
    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    delegateCompInitializer.setScoreOracle(_newScoreOracle);
  }
}
