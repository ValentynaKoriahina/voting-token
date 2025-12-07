// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./CommonRules.sol";
import "./customErrors/Errors.sol";

abstract contract ERC20 is IERC20, CommonRules {
    string internal _name;
    string internal _symbol;
    uint256 internal _decimals;

    mapping(address => uint256) internal balances;
    mapping(address => mapping(address => uint256)) internal allowances;
    uint256 internal _totalSupply;

    // Инициализатор стал internal и был переименован.
    // Модификатор 'initializer' удален. Он будет в главном контракте.
    function _initializeERC20(
        string memory name_,
        string memory symbol_
    ) internal {
        _name = name_;
        _symbol = symbol_;
        // For upgradeable proxies default storage is zero, so set decimals explicitly
        _decimals = 18;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return uint8(_decimals);
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
        return balances[account];
    }

    function transfer(
        address _to,
        uint256 _value
    ) external override returns (bool success) {
        address _from = msg.sender;
        proceedTransfer(_from, _value, _to);
        return (true);
    }

    function allowance(
        address _owner,
        address _spender
    ) external view override returns (uint256 remaining) {
        return (allowances[_owner][_spender]);
    }

    function approve(
        address _spender,
        uint256 _value
    ) external override returns (bool success) {
        address _owner = msg.sender;
        allowances[_owner][_spender] = _value;
        emit Approval(_owner, _spender, _value);
        return (true);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external override returns (bool success) {
        if (allowances[_from][msg.sender] < _value) revert AllowanceExceeded();
        proceedTransfer(_from, _value, _to);
        allowances[_from][msg.sender] -= _value;

        return (true);
    }

    function proceedTransfer(
        address _from,
        uint256 _value,
        address _to
    ) internal notFrozen(msg.sender) {
        if (balances[_from] < _value) revert InsufficientBalance();
        balances[_from] -= _value;
        balances[_to] += _value;
        emit Transfer(_from, _to, _value);
    }
}
