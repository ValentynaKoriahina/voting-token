// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITransparentProxy {
    function _setImplementation(address newImpl) internal;
    function _setAdmin(address newAdmin) internal;
}
