// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {ObolStaker, Staker} from "src/ObolStaker.sol";
import {RebasingStakedObol} from "src/RebasingStakedObol.sol";
import {IERC20Staking} from "staker/interfaces/IERC20Staking.sol";

contract ClaimAndDistributeRewards is Script {
  address public deployer;
  uint256 public deployerPrivateKey;

  ObolStaker staker = ObolStaker(0x30641013934ec7625c9e73a4D63aab4201004259);
  RebasingStakedObol rLst = RebasingStakedObol(0x1932e815254c53B3Ecd81CECf252A5AC7f0e8BeA);
  IERC20Staking obol = IERC20Staking(0x0B010000b7624eb9B3DfBC279673C76E9D29D5F7);
  uint256 payoutAmount;
  uint256 maxProfit = 20e18;
  Staker.DepositIdentifier[] deposits;

  function setUp() public virtual {
    deployerPrivateKey = vm.envOr(
      "DEPLOYER_PRIVATE_KEY",
      uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
    );
    deployer = vm.rememberKey(deployerPrivateKey);

    payoutAmount = rLst.payoutAmount();

    console2.log("Deploying from", deployer);
  }

  function run() public virtual {
    uint256 _rewardsSum = 0;
    uint256 _id = 0;

    while (true) {
      _id += 1; // Skip the 0th deposit, not owned by the LST
      Staker.DepositIdentifier _depositId = Staker.DepositIdentifier.wrap(_id);

      (, address _owner,,,,,) = staker.deposits(_depositId);
      if (_owner == address(0)) break;
      if (_owner != address(rLst)) continue;

      uint256 _unclaimedRewards = staker.unclaimedReward(_depositId);
      if (_unclaimedRewards == 0) continue;

      // Adding this deposit would make it too profitable, we'll just keep looking instead
      if ((_rewardsSum + _unclaimedRewards) > (payoutAmount + maxProfit)) {
        console2.log("Skipping Deposit To Avoid Over Profitability", _id);
        continue;
      }

      _rewardsSum += _unclaimedRewards;
      deposits.push(_depositId);
      if (_rewardsSum > payoutAmount) break;
    }

    console2.log("Payout Amount", payoutAmount);
    console2.log("Checked up to Deposit", _id);
    console2.log("Number of Deposits to Claim", deposits.length);
    console2.log("Claimable Rewards", _rewardsSum);

    if (_rewardsSum > (payoutAmount + maxProfit)) {
      console2.log("Profit Too High");
      return;
    }

    if (_rewardsSum < payoutAmount) {
      console2.log("Not Profitable");
      return;
    }

    vm.startBroadcast(deployer);
    obol.approve(address(rLst), type(uint256).max);
    rLst.claimAndDistributeReward(deployer, payoutAmount, deposits);
    vm.stopBroadcast();
  }
}
