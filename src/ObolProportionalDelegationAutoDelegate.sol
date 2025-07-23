//  SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

interface IVotingPowerTracker {}

// - At some fixed interval the oracle updates DRS scores
// - When DRS scores are updated the voting power, total voting voting is snapshotted
// - Only addresses with a DRS above the threshold will get a proportional amount of the token.
// - Provide simple UX
//   - Maybe a pasthrough castVoteWithSigAndParams
// - Rolling window that determines when a new snapshot for vote weight is taken
// - Anytime the total vote, and individual's voting power is updated we create a checkpoint.
//   - This way we can determine the voting weight, proportion when they go below the threshold we
// checkpoint a 0.
contract ObolProportionalSupportAutoDelegate {
  IVotingPowerTracker public VOTING_POWER_TRACKER;
  IGovernor public GOVERNOR;
  // 1. Read the binary eligibility oracle weights
  // 2. Allow voting via signature, passthrough to the governor
  mapping(uint256 _proposalId => mapping(address _voter => bool _hasVoted)) hasVoted;

  // Use the counting simple enum
  enum VoteType {
      Against,
      For,
      Abstain
  }


  constructor(address _votingPowerTracker, address _governor) {
    IVotingPowerTracker VOTING_POWER_TRACKER = IVotingPowerTracker(_votingPowerTracker);
	IGovernor GOVERNOR = IGovernor(_governance);
  }

  // 1. Takes in signature
  // 2. Verifies vote matches what is in signature
  function castDelegateVote(
        uint256 _proposalId,
        uint8 _support,
        address _voter,
        bytes memory signature
  ) public {
		  // TODO real revert
		  if (hasVoted[_proposalId][_voter] == true) revert();
		  uint256 _votingPowerCheckpoints = VOTING_POWER_TRACKER.votingPowerCheckpoints(_voter);
		  // Stopped here get the checkpoint and add it to the correct preference
		  uint128 _againstVotes = 0;
		  uint128 _forVotes = 0;
		  uint128 _abstainVotes = 0
		  if (_support == uint8(VoteType.Against)) {
				  _againstVotes = _totalVotes
		  }
		  bytes memory params = abi.encodePacked(_againstVotes, _forVotes, _abstainVotes);
		  GOVERNOR.castVote(_proposalId, _support, "", params);
		  // Subject to frontrunning
		  // not a fan of this desing
		  GOVERNOR.castVoteBySig(_proposalId, _support, _voter);

  }


}
