// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./VotingRules.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol"; // !!!

// IERC20Metadata
contract ERC20 is IERC20, VotingRules {
    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;

    error AllowanceExceeded();
    error InsufficientBalance();


    mapping(address => uint256) internal balances;
    mapping(address => mapping(address => uint256)) internal allowances;
    uint256 internal _totalSupply;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        (_name, _symbol, _decimals) = (name_, symbol_, decimals_);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(
        address _owner
    ) public view returns (uint256 balance) {
        return (balances[_owner]);
    }

    function transfer(
        address _to,
        uint256 _value
    ) external override returns (bool success) {
        address _from = msg.sender;
        proceedTransfer(_from, _value, _to);
        return (true);
    }

    // Возвращает, сколько токенов spender ещё может потратить у owner
    function allowance(
        address _owner,
        address _spender
    ) external view override returns (uint256 remaining) {
        return (allowances[_owner][_spender]);
    }

    // Устанавливаем разрешение для другого адреса тратить токены владельца
    function approve(
        address _spender,
        uint256 _value
    ) external override returns (bool success) {
        address _owner = msg.sender;
        allowances[_owner][_spender] = _value;
        emit Approval(_owner, _spender, _value);
        return (true);
    }

    //  transferFrom используется, когда кто-то переводит чужие токены с разрешения владельца.
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external override returns (bool success) {
        if (allowances[_from][msg.sender] < _value) revert AllowanceExceeded();
        proceedTransfer(_from, _value, _to);
        allowances[_from][msg.sender] -= _value; // Уменьшаем лимит после перевода — требование ERC-20

        return (true);
    }

    function proceedTransfer(
        address _from,
        uint256 _value,
        address _to
    ) internal notFrozen(_from) {
        if (balances[_from] < _value) revert InsufficientBalance();
        balances[_from] -= _value;
        balances[_to] += _value;
        emit Transfer(_from, _to, _value);
    }
}
