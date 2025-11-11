// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./VotingToken_UUPSproxyStorage.sol";

contract VotingToken_UUPSproxy is VotingToken_UUPSproxyStorage {
    event Upgraded(
        address indexed previousImplementation,
        address indexed newImplementation
    );

    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);

    constructor(address implementation_, address admin_) {
        _setImplementation(implementation_);
        _setAdmin(admin_);
    }

    // ловит все остальные неизвестные вызовы
    fallback() external payable {
        _delegate(_getImplementation());
    }

    // ловит голые платежи ETH
    receive() external payable {
        _delegate(_getImplementation());
    }

    function _delegate(address impl) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
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

    function implementation() external view returns (address) {
        return _getImplementation();
    }

    function admin() external view returns (address) {
        return _getAdmin();
    }
}

/**
//* function _delegate(address impl) internal {
//*   assembly {
        //  Копируем calldata (входные данные) в память начиная с адреса 0
        // calldatacopy(destMem=0, srcOffset=0, len=calldatasize())
//*        calldatacopy(0, 0, calldatasize())

        // 📌 Вызываем логику через delegatecall:
        // gas()  → передаём весь оставшийся газ
        // impl   → адрес логики
        // 0      → входные данные начинаются в памяти с адреса 0
        // calldatasize() → длина входных данных
        // 0      → куда писать output (мы сами позже скопируем)
        // 0      → размер выделенной output-памяти (0 = мы будем использовать returndatacopy)
//*        let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)

        // 📌 Копируем возвращённые данные логики в память с адреса 0
        // returndatacopy(destMem=0, srcOffset=0, len=returndatasize())
//*        returndatacopy(0, 0, returndatasize())

        // 📌 Если delegatecall вернул 0 = ошибка → пробрасываем её вызывающему
        // revert(offset=0, size=returndatasize()) → отправляет revert reason из памяти
//*       switch result
//*       case 0 { revert(0, returndatasize()) }

        // 📌 Если успех → вернуть результат логики вызывающему
        // return(offset=0, size=returndatasize())
//*       default { return(0, returndatasize()) }
//*   }
//* }
*/

/**
EVM Execution Context
встроенная фукнция gas()
 */

/**
// ? эта функция должна находиться в контракте логики, не в прокси.
// А прокси предоставляет только _setImplementation.
//*     function upgradeTo(address newImpl) external onlyAdmin() {
//*        _setImplementation(newImpl);
//*    }

    // UUPS-прокси всегда имеет правило: oбновлять реализацию может ТОЛЬКО админ
//*    modifier onlyAdmin() {
//*        require(msg.sender == _getAdmin(), "Not admin");
//*    }
*/

/**
//* ================ UUPS Upgradeable Structure ================

1) ProxyStorage.sol
   - Хранит EIP-1967 слоты implementation/admin.
   - Дает internal функции: _getImplementation(), _setImplementation(),
     _getAdmin(), _setAdmin().
   - Никакой логики и переменных приложения.

2) Proxy.sol (UUPS Proxy)
   - Наследует ProxyStorage.
   - Хранит данные приложения (через delegatecall).
   - Имеет constructor(impl, admin), fallback(), receive(), _delegate().
   - Не содержит бизнес-логики и upgradeTo().

3) LogicV1.sol (первая имплементация)
   - Наследует ProxyStorage.
   - Хранит ВСЕ переменные состояния приложения (ERC20, DAO, voting и т.д.).
   - Имеет onlyAdmin (читает admin через слоты).
   - Имеет upgradeTo() и proxiableUUID().
   - Вся бизнес-логика находится здесь.
   - Storage будет лежать в прокси, но описан в имплементации.
*/
