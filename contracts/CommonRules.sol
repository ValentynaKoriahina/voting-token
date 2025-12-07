// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./customErrors/Errors.sol";

abstract contract CommonRules {
    function _isFrozen(address user) internal view virtual returns (bool);

    modifier notFrozen(address user) {
        if (_isFrozen(user)) {
            revert LockedUntilVotingEnds();
        }
        _;
    }
}
