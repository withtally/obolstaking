// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {SingleTokenLockups} from "lib/SingleTokenLockups/contracts/SingleTokenLockups.sol";
import {VotingVault} from "lib/SingleTokenLockups/contracts/VotingVault.sol";
import {FixedStakedObol} from "src/FixedStakedObol.sol";
import {Staker} from "staker/Staker.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Eip712Helper} from "stGOV-test/helpers/Eip712Helper.sol";

interface IVotes {
  function delegate(address delegatee) external;

  function delegates(address wallet) external view returns (address delegate);

  function delegateBySig(
    address delegatee,
    uint256 nonce,
    uint256 expiry,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;
}

contract LockupsIntegration is Test, Eip712Helper {
  // Block height for mainnet after Obol Staker production deployment);
  uint256 FORK_BLOCK = 22_389_749;

  SingleTokenLockups lockups = SingleTokenLockups(0x3b9122704A20946E9Cb49b2a8616CCC0f0d61AdB);
  address lockupsAdmin = 0x42D201CC4d9C1e31c032397F54caCE2f48C1FA72;
  IERC20 obol = IERC20(0x0B010000b7624eb9B3DfBC279673C76E9D29D5F7);
  FixedStakedObol stObol = FixedStakedObol(0x6590cBBCCbE6B83eF3774Ef1904D86A7B02c2fCC);

  // Hedgey's contracts include a start time and cliff time for vesting. In Obol's case, these are
  // set to the same value, such that all tokens unlock immediately.
  uint256 START_CLIFF_TIME = 1_746_576_000;

  function setUp() public virtual {
    // Fork mainnet to run the tests
    vm.createSelectFork(vm.rpcUrl("mainnet_rpc_url"), FORK_BLOCK);
  }

  function _boundToValidPrivateKey(uint256 _privateKey) internal pure returns (uint256) {
    return bound(_privateKey, 1, SECP256K1_ORDER - 1);
  }

  function _hashTypedDataV4(
    bytes32 _typeHash,
    bytes32 _structHash,
    bytes memory _name,
    bytes memory _version,
    address _verifyingContract
  ) internal view returns (bytes32) {
    bytes32 _separator = _domainSeparator(_typeHash, _name, _version, _verifyingContract);
    return keccak256(abi.encodePacked("\x19\x01", _separator, _structHash));
  }

  function _signFixedMessage(
    bytes32 _typehash,
    address _account,
    uint256 _amount,
    uint256 _nonce,
    uint256 _expiry,
    uint256 _signerPrivateKey
  ) internal view returns (bytes memory) {
    bytes32 structHash = keccak256(abi.encode(_typehash, _account, _amount, _nonce, _expiry));
    bytes32 hash = _hashTypedDataV4(
      EIP712_DOMAIN_TYPEHASH,
      structHash,
      bytes(stObol.name()),
      bytes(stObol.version()),
      address(stObol)
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, hash);
    return abi.encodePacked(r, s, v);
  }

  function testFuzz_PerformsAnUnlockOperation(uint256 _lockupId) public {
    _lockupId = bound(_lockupId, 1, lockups.totalSupply());
    address _lockupOwner = lockups.ownerOf(_lockupId);
    VotingVault _vault = VotingVault(lockups.votingVaults(_lockupId));
    uint256 _vaultInitialObolBalance = obol.balanceOf(address(_vault));

    // Perform admin actions that make OBOL unlock-able
    vm.startPrank(lockupsAdmin);
    lockups.updateStartAndCliff(START_CLIFF_TIME, START_CLIFF_TIME);
    vm.stopPrank();

    // Jump one second past the unlock time
    vm.warp(START_CLIFF_TIME + 1);

    vm.prank(_lockupOwner);
    lockups.unlock(_lockupId);

    // Vault no longer has OBOL
    assertEq(obol.balanceOf(address(_vault)), 0);
    // Lockup Owner now hold the OBOL
    assertEq(obol.balanceOf(_lockupOwner), _vaultInitialObolBalance);
  }

  function testFuzz_PerformsAnUnlockAndStakeOperation(
    uint256 _recipientPrivateKey,
    address _delegatee,
    uint256 _amount
  ) public {
    _recipientPrivateKey = _boundToValidPrivateKey(_recipientPrivateKey);
    address _recipient = vm.addr(_recipientPrivateKey);
    vm.label(_recipient, "Recipient");
    vm.label(_delegatee, "Delegatee");
    _amount = bound(_amount, 1, 50_000_000e18);

    // Give the recipient raw Obol
    deal(address(obol), _recipient, _amount);

    // Create a lockup for our account
    vm.startPrank(_recipient);
    obol.approve(address(lockups), _amount);
    (uint256 _lockupId, address _vault) =
      lockups.createLockupWithDelegation(_recipient, _amount, _amount, _delegatee);
    vm.stopPrank();

    // Perform admin actions that make OBOL unlock-able
    vm.startPrank(lockupsAdmin);
    lockups.setStakingContract(address(stObol));
    lockups.updateStartAndCliff(START_CLIFF_TIME, START_CLIFF_TIME);
    vm.stopPrank();

    // Jump one second past the unlock time
    vm.warp(START_CLIFF_TIME + 1);

    // Signature expires in one hour
    uint256 _expiry = START_CLIFF_TIME + 3600;

    // We know the next deposit will be the second, based on the state at our fork block
    Staker.DepositIdentifier _depositId = Staker.DepositIdentifier.wrap(2);
    // Fetch appropriate nonce, which should always be zero
    uint256 _nonce = ERC20Permit(address(stObol)).nonces(_recipient);
    assertEq(_nonce, 0);

    // Create signature for updating the deposit's delegatee
    bytes memory _signature = _signFixedMessage(
      stObol.UPDATE_DEPOSIT_TYPEHASH(),
      _recipient,
      Staker.DepositIdentifier.unwrap(_depositId),
      _nonce,
      _expiry,
      _recipientPrivateKey
    );

    // Call the unlock and stake method, including the signature to perform the delegation
    vm.prank(_recipient);
    lockups.unlockAndStake(_lockupId, _nonce, _expiry, _signature);

    // The vault no longer has any tokens
    assertEq(obol.balanceOf(address(_vault)), 0);
    // The recipient has received _amount of stOBOL (this works because as of our fork block, no
    // rewards have been distributed, so 1 OBOL = 1 stOBOL)
    assertEq(stObol.balanceOf(_recipient), _amount);
    // The recipient delegates to the appropriate delegatee via stOBOL
    assertEq(stObol.delegates(_recipient), _delegatee);
  }
}
