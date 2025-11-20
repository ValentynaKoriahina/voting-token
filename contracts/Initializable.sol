// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Initializable {
    error AlreadyInitialized();

    bool private _initialized;

    modifier initializer() {
        if (_initialized) {
            revert AlreadyInitialized();
        }
        _initialized = true;
        _;
    }

    // Блокируем initialize() у логики
    function _disableInitializers() internal {
        _initialized = true;
    }
}
