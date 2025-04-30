// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Staker} from "staker/Staker.sol";
import {PercentAssertions} from "staker-test/helpers/PercentAssertions.sol";
import {ObolStaker, IERC20} from "src/ObolStaker.sol";
import {RebasingStakedObol} from "src/RebasingStakedObol.sol";
import {ObolStakerDeploymentTest} from "./ObolStaker.integration.t.sol";
import {GovLst} from "stGOV/GovLst.sol";
import {OpenZeppelinGovernorMock} from "stGOV-test/mocks/OpenZeppelinGovernorMock.sol";
import {ObolOverwhelmingSupportAutoDelegate} from "src/ObolOverwhelmingSupportAutoDelegate.sol";

contract ObolOverwhelmingSupportAutoDelegateTest is ObolStakerDeploymentTest {
  OpenZeppelinGovernorMock public governor;
  ObolOverwhelmingSupportAutoDelegate autoDelegateForTest;

  function setUp() public override {
    super.setUp();
    // Setup the governor mock
    governor = new OpenZeppelinGovernorMock();
    autoDelegateForTest = ObolOverwhelmingSupportAutoDelegate(autoDelegate);
  }

  function test_Clock() public view {
    // Check that the clock is set correctly
    assertEq(autoDelegateForTest.clock(), block.number);
  }

  function test_CLOCK_MODE() public view {
    // Check that the clock mode is set correctly
    assertEq(autoDelegateForTest.CLOCK_MODE(), "mode=blocknumber&from=default");
  }

  function testFuzz_CastVote(address _voter, uint256 _proposalId) public {
    vm.assume(_voter != address(0));
    vm.assume(_voter != address(autoDelegate));
    vm.assume(_voter != address(governor));

    // Ensure the proposal ID is within a reasonable range
    _proposalId = bound(_proposalId, 1, 1000);

    // create a proposal in the mock governor that has already reached quorum to allow autoDelegate
    // to vote
    uint256 _endBlock = block.number + 100; // Set the end block for the proposal
    governor.__setProposals(_proposalId, _endBlock, governor.quorum(block.number), 0);
    // Set the quorum votes to a realistic value
    governor.__setQuorumVotes(40_000_000e18); // 40,000,000 = 4% of GOV

    uint256 _beforeVotes = governor.mockProposalVotes(_proposalId);

    // Cast a vote on the proposal via the autoDelegate
    vm.prank(_voter);
    autoDelegateForTest.castVote(address(governor), _proposalId);

    // Check that the vote was cast successfully
    assertEq(governor.mockProposalVotes(_proposalId), uint8(autoDelegateForTest.FOR()));
    assertGt(governor.mockProposalVotes(_proposalId), _beforeVotes);
  }
}
