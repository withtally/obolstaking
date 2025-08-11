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

  function getOracleEligibilityModule() public virtual override returns (IOracleEligibilityModule) {
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

// 1. Revert if not score oracle
// 2. Update score when not eligible, but don't initialize
// 3. Update score when delegate initialized
// 4. Initialize delegate when above the threshold and not initialized
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
