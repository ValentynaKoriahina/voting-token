// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Initializable {
    bool private _initialized;
    bool private _initializing;

    modifier initializer() {
        require(!_initialized || _initializing, "Already initialized");
        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    function initialized() public view returns (bool) {
        return _initialized;
    }
}
