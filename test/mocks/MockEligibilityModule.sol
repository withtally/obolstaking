// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEligibilityModule} from "src/interfaces/IEligibilityModule.sol";

contract MockEligibilityModule is IEligibilityModule {
  /*///////////////////////////////////////////////////////////////
                          Storage
  //////////////////////////////////////////////////////////////*/

  bool public __mockIsOraclePaused;
  bool public __mockIsOracleStale;
  mapping(address => bool) public __mockDelegateeEligibility;

  /*///////////////////////////////////////////////////////////////
                          External Functions
  //////////////////////////////////////////////////////////////*/

  function isOraclePaused() external view override returns (bool) {
    return __mockIsOraclePaused;
  }

  function isOracleStale() external view override returns (bool) {
    return __mockIsOracleStale;
  }

  function isDelegateeEligible(address _delegatee) external view override returns (bool) {
    return __mockDelegateeEligibility[_delegatee];
  }

  /*///////////////////////////////////////////////////////////////
                        Custom Functions
  //////////////////////////////////////////////////////////////*/

  /// @dev Sets the mock oracle paused state
  function __setMockIsOraclePaused(bool _isPaused) external {
    __mockIsOraclePaused = _isPaused;
  }

  /// @dev Sets the mock oracle stale state
  function __setMockIsOracleStale(bool _isStale) external {
    __mockIsOracleStale = _isStale;
  }

  /// @dev Sets the mock eligibility for a specific delegatee
  function __setMockDelegateeEligibility(address _delegatee, bool _isEligible) external {
    __mockDelegateeEligibility[_delegatee] = _isEligible;
  }
}
