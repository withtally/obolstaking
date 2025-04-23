// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {Staker, IERC20} from "staker/Staker.sol";
import {GovLst} from "stGOV/GovLst.sol";
import {IEarningPowerCalculator} from "staker/interfaces/IEarningPowerCalculator.sol";
import {IERC20Staking} from "staker/interfaces/IERC20Staking.sol";
import {ObolStaker} from "src/ObolStaker.sol";
import {RebasingStakedObol} from "src/RebasingStakedObol.sol";

abstract contract BaseObolDeploy is Script {
  ObolStaker internal staker;
  address public deployer;
  uint256 public deployerPrivateKey;

  struct ObolStakerParams {
    IERC20 rewardsToken;
    IERC20Staking stakeToken;
    uint256 maxBumpTip;
    address admin;
    string name;
  }

  function setUp() public virtual {
    deployerPrivateKey = vm.envOr(
      "DEPLOYER_PRIVATE_KEY",
      uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
    );
    deployer = vm.rememberKey(deployerPrivateKey);

    console2.log("Deploying from", deployer);
  }

  function _deployEarningPowerCalculator() internal virtual returns (IEarningPowerCalculator);

  function _getOrDeployAutoDelegate() internal virtual returns (address);

  function _getStakerConfig() public view virtual returns (ObolStakerParams memory);

  function _getLstConfig(address _autoDelegate)
    public
    view
    virtual
    returns (GovLst.ConstructorParams memory);

  function _deployRewardNotifiers() internal virtual returns (address[] memory) {
    return new address[](0);
  }

  function run()
    public
    virtual
    returns (
      ObolStaker _staker,
      IEarningPowerCalculator _calculator,
      RebasingStakedObol _rebasingLst,
      address _autoDelegate
    )
  {
    _calculator = _deployEarningPowerCalculator();
    console2.log("Deployed Earning Power Calculator:", address(_calculator));

    ObolStakerParams memory _stakerParams = _getStakerConfig();

    // Deploy the core staker contract
    vm.broadcast(deployer);
    staker = new ObolStaker(
      _stakerParams.rewardsToken,
      _stakerParams.stakeToken,
      _calculator,
      _stakerParams.maxBumpTip,
      deployer,
      _stakerParams.name
    );
    console2.log("Deployed Obol Staker:", address(staker));
    _staker = staker;

    // Deploy and set the reward notifiers
    address[] memory _notifiers = _deployRewardNotifiers();
    for (uint256 _i = 0; _i < _notifiers.length; _i++) {
      vm.broadcast(deployer);
      staker.setRewardNotifier(_notifiers[_i], true);
      console2.log("Deployed and Configured Notifier:", _notifiers[_i]);
    }

    // Give admin to the proper address
    vm.broadcast(deployer);
    staker.setAdmin(_stakerParams.admin);
    console2.log("Updated Staker admin to:", _stakerParams.admin);

    // Initialize the first deposit to ensure it's not owned by the LST, as this breaks the LST
    // accounting system.
    vm.broadcast(deployer);
    Staker.DepositIdentifier _depositId = staker.stake(0, deployer);
    console2.log("Deployer Claimed Deposit #", Staker.DepositIdentifier.unwrap(_depositId));

    // Get the address of the LST's auto delegate, which may be deployed in the process
    _autoDelegate = _getOrDeployAutoDelegate();
    console2.log("Using Auto Delegate:", _autoDelegate);

    // Get the LST config
    GovLst.ConstructorParams memory _lstParams = _getLstConfig(_autoDelegate);

    uint256 _deployerNonce = vm.getNonce(deployer);
    // +1 because approval will happen first
    address _computedLstAddress = vm.computeCreateAddress(deployer, _deployerNonce + 1);

    // Approve the (yet to be deployed) LST address to pull tokens during its deployment
    vm.broadcast(deployer);
    _stakerParams.stakeToken.approve(_computedLstAddress, _lstParams.stakeToBurn);
    console2.log("Approved", _computedLstAddress, "for", _lstParams.stakeToBurn);

    // Deploy the Rebasing LST which also deploys the Fixed LST
    vm.broadcast(deployer);
    _rebasingLst = new RebasingStakedObol(_lstParams);

    console2.log("Deployed Rebasing Obol LST:", address(_rebasingLst));
    console2.log("Deployed Fixed Obol LST:", address(_rebasingLst.FIXED_LST()));
  }
}
