// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.28;

import {console2} from "forge-std/Script.sol";
import {ObolStaker} from "src/ObolStaker.sol";
import {RebasingStakedObol} from "src/RebasingStakedObol.sol";
import {IEarningPowerCalculator} from "staker/interfaces/IEarningPowerCalculator.sol";
import {IdentityEarningPowerCalculator} from "staker/calculators/IdentityEarningPowerCalculator.sol";
import {IERC20Staking} from "staker/interfaces/IERC20Staking.sol";
import {GovLst} from "stGOV/GovLst.sol";
import {BaseObolDeploy as Base} from "script/BaseObolDeploy.sol";
import {TransferRewardNotifier} from "staker/notifiers/TransferRewardNotifier.sol";
import {ObolOverwhelmingSupportAutoDelegate} from "src/ObolOverwhelmingSupportAutoDelegate.sol";

contract MainnetObolDeploy is Base {
  TransferRewardNotifier transferNotifier;

  // Mainnet OBOL token contract
  IERC20Staking OBOL_TOKEN = IERC20Staking(0x0B010000b7624eb9B3DfBC279673C76E9D29D5F7);
  // Mainnet Obol Multisig
  address OBOL_STAKER_ADMIN = 0x42D201CC4d9C1e31c032397F54caCE2f48C1FA72;
  // Mainnet Tally Multisig
  address LST_OWNER = 0x7E90E03654732ABedF89Faf87f05BcD03ACEeFdC;

  // 275,000 OBOL every 30 days: works out to 1,650,000 OBOL over 180 days (~6 months)
  uint256 REWARD_AMOUNT = 275_000e18;
  uint256 REWARD_INTERVAL = 30 days;

  // ** Configuration for the auto delegatee **
  // The owner of Staker represents governance, so also owns the auto delegate.
  address AUTO_DELEGATE_OWNER = OBOL_STAKER_ADMIN;
  // The minimum allowable voting window that can be set, in blocks. ~1 hour, assuming 12s blocks.
  uint256 AUTO_DELEGATE_MIN_VOTING_WINDOW = 300;
  // The maximum allowable voting window that can be set, in blocks. ~10 days, assuming 12s blocks.
  uint256 AUTO_DELEGATE_MAX_VOTING_WINDOW = 72_000;
  // The initial configured voting window, in blocks. ~2 days, assuming 12s blocks.
  uint256 AUTO_DELEGATE_INITIAL_VOTING_WINDOW = 14_400;
  // Initial sub-quorum: proposal must reach 66% (in bips) of quorum for auto delegate to vote.
  uint256 AUTO_DELEGATE_SUB_QUORUM_BIPS = 6600;
  // Initial support threshold: proposal must have 90% (in bips) FOR votes for auto delegate to
  // vote.
  uint256 AUTO_DELEGATE_SUPPORT_THRESHOLD_BIPS = 9000;

  function _deployEarningPowerCalculator()
    internal
    virtual
    override
    returns (IEarningPowerCalculator)
  {
    vm.broadcast(deployer);
    IdentityEarningPowerCalculator _calculator = new IdentityEarningPowerCalculator();
    return _calculator;
  }

  function _getStakerConfig() public view virtual override returns (Base.ObolStakerParams memory) {
    return Base.ObolStakerParams({
      rewardsToken: OBOL_TOKEN,
      stakeToken: OBOL_TOKEN,
      // Max tip for bumping of 10 OBOL means even at a very low market cap, a max tip of $1. This
      // should be sufficiently high. Furthermore, since bumping will not be possible immediately,
      // because all stakers earn equally, it doesn't matter much. If the EPC is updated to
      // introduce the requirement of bumping, the max tip could also be adjusted at this time.
      maxBumpTip: 10e18,
      admin: OBOL_STAKER_ADMIN,
      name: "Obol Staker"
    });
  }

  function _deployRewardNotifiers() internal virtual override returns (address[] memory) {
    vm.broadcast(deployer);
    transferNotifier =
      new TransferRewardNotifier(staker, REWARD_AMOUNT, REWARD_INTERVAL, OBOL_STAKER_ADMIN);
    address[] memory _return = new address[](1);
    _return[0] = address(transferNotifier);
    return _return;
  }

  function _getOrDeployAutoDelegate() internal virtual override returns (address) {
    vm.broadcast(deployer);
    ObolOverwhelmingSupportAutoDelegate _autoDelegate = new ObolOverwhelmingSupportAutoDelegate(
      OBOL_STAKER_ADMIN,
      AUTO_DELEGATE_MIN_VOTING_WINDOW,
      AUTO_DELEGATE_MAX_VOTING_WINDOW,
      AUTO_DELEGATE_INITIAL_VOTING_WINDOW,
      AUTO_DELEGATE_SUB_QUORUM_BIPS,
      AUTO_DELEGATE_SUPPORT_THRESHOLD_BIPS
    );

    console2.log("Deployed Obol Auto Delegate:", address(_autoDelegate));

    return address(_autoDelegate);
  }

  function _getLstConfig(address _autoDelegate)
    public
    view
    virtual
    override
    returns (GovLst.ConstructorParams memory)
  {
    return GovLst.ConstructorParams({
      fixedLstName: "Staked Obol",
      fixedLstSymbol: "stOBOL",
      rebasingLstName: "Rebasing Staked Obol",
      rebasingLstSymbol: "rstOBOL",
      version: "1",
      // Deployed earlier in the script execution
      staker: staker,
      // Should be the address of the auto delegate deployed by the method above
      initialDefaultDelegatee: _autoDelegate,
      initialOwner: LST_OWNER,
      // A payout amount of 2,200 OBOL, given the anticipated rate of reward distributions for at
      // least the first six months, works out to reward distributions every ~5.5 to 6.5 hours.
      initialPayoutAmount: 2200e18,
      initialDelegateeGuardian: OBOL_STAKER_ADMIN,
      // Burn 0.5 OBOL to prevent inflation attacks
      stakeToBurn: 0.5e18,
      // 100% since we're using the identity calculator
      minQualifyingEarningPowerBips: 1e4
    });
  }

  function run()
    public
    override
    returns (
      ObolStaker _staker,
      IEarningPowerCalculator _calculator,
      RebasingStakedObol _rebasingLst,
      address _autoDelegate
    )
  {
    (_staker, _calculator, _rebasingLst, _autoDelegate) = super.run();
  }
}
