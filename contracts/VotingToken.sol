// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./ERC20.sol";
import "./Tradable.sol";
import "./customErrors/Errors.sol";
import "./CommonRules.sol";

contract VotingToken is Initializable, ERC20, Tradable, OwnableUpgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        uint256 tokenPrice,
        uint256 buyFee,
        uint256 sellFee
    ) public initializer {
        __Ownable_init(msg.sender);
        _initializeERC20(name, symbol);
        _initializeTradable(tokenPrice, buyFee, sellFee);
    }

    // ========= Tradable → ERC20 binding ==========

    function _getBalance(
        address owner
    ) internal view override returns (uint256) {
        return balances[owner];
    }

    function _setBalance(address owner, uint256 amount) internal override {
        balances[owner] = amount;
    }

    function _getTotalSupply() internal view override returns (uint256) {
        return _totalSupply;
    }

    function _setTotalSupply(uint256 amount) internal override {
        _totalSupply = amount;
    }

    function _tokenPrice() internal view override returns (uint256) {
        return tokenPrice;
    }

    function _emitTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        emit Transfer(from, to, amount);
    }




    function mint(address to, uint256 amount) public onlyOwner {
        _totalSupply += amount;
        balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }
}
