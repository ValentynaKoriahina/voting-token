// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Initializable {
    error AlreadyInitialized();

    bool private _initialized;
    bool private _initializing;

    modifier initializer() {
        if (_initialized && !_initializing) {
            revert AlreadyInitialized();
        }

        bool isTop = !_initializing;

        if (isTop) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTop) {
            _initializing = false;
        }
    }

    // Запрещает initialize() для имплементации
    function _disableInitializers() internal {
        _initialized = true;
    }
}
