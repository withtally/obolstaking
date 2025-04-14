//  SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {OverwhelmingSupportAutoDelegate} from
  "stGOV/auto-delegates/OverwhelmingSupportAutoDelegate.sol";
import {AutoDelegateOpenZeppelinGovernor} from
  "stGOV/auto-delegates/extensions/AutoDelegateOpenZeppelinGovernor.sol";
import {BlockNumberClockMode} from "stGOV/auto-delegates/extensions/BlockNumberClockMode.sol";

/// @title FixedStakedObol
/// @author [ScopeLift](https://scopelift.co)
/// @notice The initial auto delegate used by stOBOL, based on the Overwhelming Support gadget
/// implemented in the Tally stGOV repo. This mechanism allows undelegated voting weight from
/// stOBOL to participate in governance only by voting FOR proposals that have high consensus from
/// the DAO but haven't reached quorum. See OverwhelmingSupportAutoDelegate.sol for details.
contract ObolOverwhelmingSupportAutoDelegate is
  OverwhelmingSupportAutoDelegate,
  AutoDelegateOpenZeppelinGovernor,
  BlockNumberClockMode
{
  /// @notice Initializes the auto delegate.
  /// @param _initialOwner The address that will be set as the initial owner of the contract.
  /// @param _votingWindow The initial voting window value, in timepoint units.
  /// @param _subQuorumBips The initial sub-quorum votes percentage in basis points.
  /// @param _supportThreshold The initial support threshold in basis points.
  constructor(
    address _initialOwner,
    uint256 _minVotingWindow,
    uint256 _maxVotingWindow,
    uint256 _votingWindow,
    uint256 _subQuorumBips,
    uint256 _supportThreshold
  )
    OverwhelmingSupportAutoDelegate(
      _initialOwner,
      _minVotingWindow,
      _maxVotingWindow,
      _votingWindow,
      _subQuorumBips,
      _supportThreshold
    )
  {}

  /// @inheritdoc BlockNumberClockMode
  /// @dev We override this function to resolve ambiguity between inherited contracts.
  function clock()
    public
    view
    override(OverwhelmingSupportAutoDelegate, AutoDelegateOpenZeppelinGovernor, BlockNumberClockMode)
    returns (uint48)
  {
    return BlockNumberClockMode.clock();
  }

  /// @inheritdoc BlockNumberClockMode
  /// @dev We override this function to resolve ambiguity between inherited contracts.
  function CLOCK_MODE()
    public
    view
    override(OverwhelmingSupportAutoDelegate, BlockNumberClockMode)
    returns (string memory)
  {
    return BlockNumberClockMode.CLOCK_MODE();
  }

  /// @inheritdoc AutoDelegateOpenZeppelinGovernor
  /// @dev We override this function to resolve ambiguity between inherited contracts.
  function _castVote(address _governor, uint256 _proposalId)
    internal
    override(OverwhelmingSupportAutoDelegate, AutoDelegateOpenZeppelinGovernor)
  {
    AutoDelegateOpenZeppelinGovernor._castVote(_governor, _proposalId);
  }

  /// @inheritdoc AutoDelegateOpenZeppelinGovernor
  /// @dev We override this function to resolve ambiguity between inherited contracts.
  function _getProposalDetails(address _governor, uint256 _proposalId)
    internal
    view
    override(OverwhelmingSupportAutoDelegate, AutoDelegateOpenZeppelinGovernor)
    returns (
      uint256 _proposalDeadline,
      uint256 _forVotes,
      uint256 _againstVotes,
      uint256 _quorumVotes
    )
  {
    return AutoDelegateOpenZeppelinGovernor._getProposalDetails(_governor, _proposalId);
  }
}
