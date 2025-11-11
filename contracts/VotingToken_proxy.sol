// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


contract Proxy {
    address public implementation;
    address public admin;

    event Upgraded(address indexed newImplementation);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);

    constructor(address _implementation) {
        require(_implementation != address(0), "Invalid implementation");
        admin = msg.sender;
        implementation = _implementation;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    function upgradeTo(address newImplementation) external onlyAdmin {
        require(newImplementation != address(0), "Invalid implementation");
        implementation = newImplementation;
        emit Upgraded(newImplementation);
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid admin");
        emit AdminChanged(admin, newAdmin);
        admin = newAdmin;
    }

    fallback() external payable {
        _delegate(implementation);
    }

    receive() external payable {
        _delegate(implementation);
    }

    function _delegate(address impl) internal {
        assembly {
            // копия входных данныех
            calldatacopy(0, 0, calldatasize())
            // delegatecall выполняется используя хранилище прокси)
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            // копируем возвращаемые данные
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
