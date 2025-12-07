// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./ERC20.sol";
import "./Tradable.sol";
import "./Voting.sol";
import "./customErrors/Errors.sol";
import "./CommonRules.sol";

contract VotingToken is
    Initializable,
    ERC20,
    Tradable,
    Voting,
    OwnableUpgradeable
{
    constructor() {
        _disableInitializers();
    }

    uint256 tokenPrice; // wei ЗА ОДИН ПОЛНЫЙ ТОКЕН

    function initialize(
        string memory name,
        string memory symbol,
        uint256 tokenPrice_,
        uint256 buyFee,
        uint256 sellFee
    ) public initializer {
        tokenPrice = tokenPrice_;
        __Ownable_init(msg.sender);
        _initializeERC20(name, symbol);
        _initializeTradable(buyFee, sellFee);
        _initializeVote(3 days);
    }

    function _applyNewPrice(uint256 price) internal override {
        tokenPrice = price;
    }

    function _getBalance(
        address owner
    ) internal view override(Tradable, Voting) returns (uint256) {
        return balances[owner];
    }

    function _setBalance(
        address owner,
        uint256 amount
    ) internal override(Tradable) {
        balances[owner] = amount;
    }

    function _getTotalSupply()
        internal
        view
        override(Tradable, Voting)
        returns (uint256)
    {
        return _totalSupply;
    }

    function _setTotalSupply(uint256 amount) internal override(Tradable) {
        _totalSupply = amount;
    }

    function _tokenPrice() internal view override(Tradable) returns (uint256) {
        return tokenPrice;
    }

    function _emitTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(Tradable) {
        emit Transfer(from, to, amount);
    }

    function mint(address account, uint256 amount) external onlyOwner {
        balances[account] += amount;
        _totalSupply += amount;
        emit Transfer(address(0), account, amount);
    }
}
