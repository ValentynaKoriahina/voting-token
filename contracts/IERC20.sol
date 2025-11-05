// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// https://eips.ethereum.org/EIPS/eip-20

interface IERC20 {
    // Количество всех выпущенных токенов
    function totalSupply() external view  returns(uint256);
    // Баланс конкретного пользователя
    function balanceOf(address _owner) external view returns(uint256 balance);
    // Перевод токенов получателю
    function transfer(address _to, uint256 _value) external returns (bool success);
    // Разрешение тратить токены от имени владельца
    function approve(address _spender, uint256 _value) external returns (bool success);
    // Проверка, сколько токенов разрешено тратить
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);
    // Перевод токенов от имени владельца
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    
    // Событие при переводе
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    // Событие при изменении разрешения
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}
