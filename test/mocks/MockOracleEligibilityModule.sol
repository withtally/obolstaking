// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IOracleEligibilityModule} from "src/interfaces/IOracleEligibilityModule.sol";

contract MockOracleEligibilityModule is IOracleEligibilityModule {
  /*///////////////////////////////////////////////////////////////
                          Storage
  //////////////////////////////////////////////////////////////*/

  bool public __mockIsOraclePaused;
  bool public __mockIsOracleStale;
  mapping(address => bool) public __mockDelegateeEligibility;
  mapping(address => uint256) public __delegateeScores;

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

  function updateDelegateeScore(address _delegatee, uint256 _newScore) external virtual override {
    __delegateeScores[_delegatee] = _newScore;
  }

  function updateDelegateeScores(DelegateeScoreUpdate[] calldata _delegateeScoreUpdates)
    external
    virtual
    override
  {
    for (uint256 _i = 0; _i < _delegateeScoreUpdates.length; _i++) {
      __delegateeScores[_delegateeScoreUpdates[_i].delegatee] = _delegateeScoreUpdates[_i].newScore;
    }
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
