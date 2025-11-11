// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract VotingToken_UUPSproxyStorage {
    bytes32 internal constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc; // EIP-1967 impl слот

    bytes32 internal constant _ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e8e0a9d99b4b417e0dca44b12c0d33d6a; // EIP-1967 admin слот

    function _getImplementation() internal view returns (address impl) {
        assembly {
            impl := sload(_IMPLEMENTATION_SLOT)
        }
    }

    function _getAdmin() internal view returns (address adm) {
        assembly {
            adm := sload(_ADMIN_SLOT)
        }
    }

    function _setImplementation(address newImpl) internal {
        assembly {
            sstore(_IMPLEMENTATION_SLOT, newImpl)
        }
    }
    
    function _setAdmin(address newAdmin) internal {
        assembly {
            sstore(_ADMIN_SLOT, newAdmin)
        }
    }
}
